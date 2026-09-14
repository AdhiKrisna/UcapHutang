import Foundation
import Speech
import AVFoundation
import Observation

@Observable
final class SpeechRecognizer: SpeechTranscribing {
    private(set) var state: SpeechRecognizerState = .idle
    private(set) var liveTranscript = ""
    private(set) var audioLevel: Float = 0.0

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "id-ID")) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @ObservationIgnored private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    @ObservationIgnored private var hasInstalledInputTap = false
    @ObservationIgnored private var activeTranscript: String = ""
    @ObservationIgnored private var transcriptContinuation: CheckedContinuation<String, Never>?

    private static let vocabulary = [
        "nalangin", "nalagin", "talangin", "bayarin", "nombokin", "tombokin",
        "ngutang", "piutang", "hutang", "pinjem", "minjem", "minjemin",
        "split bill", "splitbill", "patungan", "bagi rata", "urunan",
        "gacoan", "ramen", "kopi", "bensin", "konser", "tiket",
        "ribu", "juta", "jt", "rb", "k"
    ]

    init() {}

    var usesOnDeviceRecognition: Bool {
        speechRecognizer?.supportsOnDeviceRecognition ?? false
    }

    func start() async throws {
        liveTranscript = ""
        activeTranscript = ""

        let microphoneGranted = await AVAudioApplication.requestRecordPermission()
        guard microphoneGranted else {
            throw SpeechPermissionError.microphoneDenied
        }

        let status = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { @Sendable status in
                continuation.resume(returning: status)
            }
        }
        switch status {
        case .authorized:
            break
        case .denied:
            throw SpeechPermissionError.speechDenied
        case .restricted:
            throw SpeechPermissionError.restricted
        case .notDetermined:
            throw SpeechRecognitionError.authorizationNotDetermined
        @unknown default:
            throw SpeechRecognitionError.authorizationUnknown
        }

        try beginRecognition()
    }

    func finish() async -> String {
        guard state == .listening else {
            return activeTranscript
        }
        state = .finalizing
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
        }
        removeInputTap()

        return await withCheckedContinuation { continuation in
            self.transcriptContinuation = continuation

            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 750_000_000)
                guard let self, self.state == .finalizing else { return }
                self.finishTaskAndCleanup(finalTranscript: self.activeTranscript)
            }
        }
    }

    func cancel() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
        }
        removeInputTap()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        state = .idle
        audioLevel = 0.0

        if let continuation = transcriptContinuation {
            transcriptContinuation = nil
            continuation.resume(returning: activeTranscript)
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func beginRecognition() throws {
        if recognitionTask != nil {
            cancel()
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw SpeechRecognitionError.audioSession(error.localizedDescription)
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.addsPunctuation = true
        request.requiresOnDeviceRecognition = usesOnDeviceRecognition
        request.contextualStrings = Self.vocabulary
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let text = result.bestTranscription.formattedString
                self.activeTranscript = text
                Task { @MainActor in
                    self.liveTranscript = text
                }
                if result.isFinal {
                    self.finishTaskAndCleanup(finalTranscript: text)
                }
            }

            if let error {
                if self.state == .finalizing {
                    self.finishTaskAndCleanup(finalTranscript: self.activeTranscript)
                } else if self.state == .listening {
                    self.finishTaskAndCleanup(finalTranscript: self.activeTranscript)
                    self.state = .failed("Speech recognition error: \(error.localizedDescription)")
                }
            }
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self else { return }
            self.recognitionRequest?.append(buffer)
            self.processAudioLevel(from: buffer)
        }
        hasInstalledInputTap = true

        audioEngine.prepare()
        do {
            try audioEngine.start()
            state = .listening
        } catch {
            removeInputTap()
            throw SpeechRecognitionError.audioEngine(error.localizedDescription)
        }
    }

    private func finishTaskAndCleanup(finalTranscript: String) {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        state = .idle
        audioLevel = 0.0

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        if let continuation = transcriptContinuation {
            transcriptContinuation = nil
            continuation.resume(returning: finalTranscript)
        }
    }

    private func processAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))

        var sum: Float = 0.0
        for sample in samples {
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(buffer.frameLength))
        let db = 20 * log10(max(rms, 0.0001))

        let minDb: Float = -50.0
        let maxDb: Float = -5.0
        let normalized = max(0.0, min(1.0, (db - minDb) / (maxDb - minDb)))

        Task { @MainActor [weak self] in
            guard let self, self.state == .listening else { return }
            self.audioLevel = (self.audioLevel * 0.4) + (normalized * 0.6)
        }
    }

    private func removeInputTap() {
        guard hasInstalledInputTap else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        hasInstalledInputTap = false
    }
}
