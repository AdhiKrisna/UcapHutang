import Foundation
import Observation

@Observable
final class CatatViewModel {
    let flow: CaptureFlow
    let speech: any SpeechTranscribing
    private let capture: any VoiceCapturing

    private(set) var isStartingRecording = false
    private(set) var isProcessing = false
    private(set) var savedDraftID: UUID?
    private(set) var permissionMessage: String?
    var errorMessage: String?

    @ObservationIgnored private var processingTask: Task<Void, Never>?

    init(flow: CaptureFlow, speech: any SpeechTranscribing, capture: any VoiceCapturing) {
        self.flow = flow
        self.speech = speech
        self.capture = capture
    }

    var isListening: Bool {
        isStartingRecording || speech.state == .listening
    }

    var stageHeadline: String {
        if isProcessing { return "Menganalisis data..." }
        if speech.state == .finalizing { return "Menyelesaikan transkrip..." }
        if isListening { return "Mendengarkan..." }
        return ""
    }

    var recordButtonLabel: String {
        isListening ? "Berhenti merekam" : "Mulai merekam"
    }

    func handleMicTap() async {
        guard !isProcessing, !isStartingRecording else { return }
        if speech.state == .listening {
            await finishAndProcess()
        } else {
            await startRecording()
        }
    }

    func restartRecording() async {
        guard !isProcessing else { return }
        speech.cancel()
        await startRecording()
    }

    func handleSpeechStateChange(_ state: SpeechRecognizerState) {
        if case .failed(let message) = state, !isProcessing {
            errorMessage = message
        }
    }

    func cancel() {
        speech.cancel()
        processingTask?.cancel()
        processingTask = nil
        isStartingRecording = false
        isProcessing = false
    }

    private func startRecording() async {
        permissionMessage = nil
        isStartingRecording = true
        defer { isStartingRecording = false }
        do {
            try await speech.start()
        } catch let error as SpeechPermissionError {
            permissionMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func finishAndProcess() async {
        isProcessing = true
        let task = Task {
            defer { self.isProcessing = false }
            let finalTranscript = await self.speech.finish()
            guard !Task.isCancelled else { return }

            let candidate = finalTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? self.speech.liveTranscript
                : finalTranscript
            let transcript = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !transcript.isEmpty else {
                self.errorMessage = "Suara tidak terdeteksi. Silakan coba lagi."
                return
            }

            do {
                let draftID = try await self.capture.process(flow: self.flow, transcript: transcript)
                guard !Task.isCancelled else { return }
                self.savedDraftID = draftID
            } catch {
                guard !Task.isCancelled else { return }
                self.errorMessage = error.localizedDescription
            }
        }
        processingTask = task
        await task.value
        processingTask = nil
    }
}
