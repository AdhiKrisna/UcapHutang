import Foundation
import Speech
import AVFoundation
import Combine

public enum SpeechRecognizerState: Equatable, Sendable {
    case idle
    case listening
    case finalizing
    case failed(String)
}

@MainActor
public final class SpeechRecognizer: ObservableObject {
    @Published public var state: SpeechRecognizerState = .idle
    @Published public var isRecording = false
    @Published public var errorMessage: String?
    @Published public var audioLevel: Float = 0.0

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "id-ID")) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var hasInstalledInputTap = false
    private var activeTranscript: String = ""
    private var transcriptContinuation: CheckedContinuation<String, Never>?

    public init() {}

    public func startRecording(onTranscript: @escaping @MainActor (String) -> Void) {
        errorMessage = nil
        activeTranscript = ""

        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch authStatus {
                case .authorized:
                    self.performStartRecording(onTranscript: onTranscript)
                case .denied:
                    self.setError("Izin Speech Recognition ditolak. Buka Settings untuk mengaktifkan.")
                case .restricted:
                    self.setError("Speech Recognition dibatasi pada perangkat ini.")
                case .notDetermined:
                    self.setError("Izin belum ditentukan.")
                @unknown default:
                    self.setError("Status otorisasi tidak dikenal.")
                }
            }
        }
    }

    private func performStartRecording(onTranscript: @escaping @MainActor (String) -> Void) {
        if recognitionTask != nil {
            cancelRecording()
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            setError("Gagal menginisialisasi AVAudioSession: \(error.localizedDescription)")
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation

        if #available(iOS 16.0, *) {
            request.addsPunctuation = true
        }

        let baseVocabulary = [
            "nalangin", "nalagin", "talangin", "bayarin", "nombokin", "tombokin",
            "ngutang", "piutang", "hutang", "pinjem", "minjem", "minjemin",
            "split bill", "splitbill", "patungan", "bagi rata", "urunan",
            "gacoan", "ramen", "kopi", "bensin", "konser", "tiket",
            "ribu", "juta", "jt", "rb", "k"
        ]
        request.contextualStrings = Array(baseVocabulary.prefix(100))
        self.recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result = result {
                let text = result.bestTranscription.formattedString
                self.activeTranscript = text
                Task { @MainActor in
                    onTranscript(text)
                }

                if result.isFinal {
                    self.finishTaskAndCleanup(finalTranscript: text)
                }
            }

            if let error = error {
                if self.state == .finalizing {
                    self.finishTaskAndCleanup(finalTranscript: self.activeTranscript)
                } else if self.isRecording {
                    self.setError("Speech recognition error: \(error.localizedDescription)")
                    self.finishTaskAndCleanup(finalTranscript: self.activeTranscript)
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
            isRecording = true
            state = .listening
        } catch {
            removeInputTap()
            setError("Gagal memulai AudioEngine: \(error.localizedDescription)")
        }
    }

    public func finishRecording() async -> String {
        guard isRecording || state == .listening else {
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

    public func cancelRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
        }
        removeInputTap()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false
        state = .idle
        audioLevel = 0.0

        if let cont = transcriptContinuation {
            transcriptContinuation = nil
            cont.resume(returning: activeTranscript)
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func finishTaskAndCleanup(finalTranscript: String) {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false
        state = .idle
        audioLevel = 0.0

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        if let cont = transcriptContinuation {
            transcriptContinuation = nil
            cont.resume(returning: finalTranscript)
        }
    }

    private func processAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let channelDataArray = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))

        var sum: Float = 0.0
        for sample in channelDataArray {
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(buffer.frameLength))
        let db = 20 * log10(max(rms, 0.0001))

        let minDb: Float = -50.0
        let maxDb: Float = -5.0
        let rawNormalized = max(0.0, min(1.0, (db - minDb) / (maxDb - minDb)))

        Task { @MainActor [weak self] in
            guard let self, self.isRecording else { return }
            let smoothed = (self.audioLevel * 0.4) + (rawNormalized * 0.6)
            self.audioLevel = smoothed
        }
    }

    private func setError(_ message: String) {
        errorMessage = message
        state = .failed(message)
        isRecording = false
    }

    private func removeInputTap() {
        guard hasInstalledInputTap else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        hasInstalledInputTap = false
    }
}
