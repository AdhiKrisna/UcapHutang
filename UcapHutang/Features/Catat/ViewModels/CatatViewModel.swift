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
    var manualTranscript = ""

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

    var canSubmitManualTranscript: Bool {
        !manualTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isListening
            && !isProcessing
    }

    func handleMicTap() async {
        guard !isProcessing, !isStartingRecording else { return }
        if speech.state == .listening {
            await finishAndProcess()
        } else {
            await startRecording()
        }
    }

    func submitManualTranscript() async {
        guard canSubmitManualTranscript else { return }
        await process(transcript: manualTranscript)
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

            await self.process(transcript: transcript)
        }
        processingTask = task
        await task.value
        processingTask = nil
    }

    private func process(transcript: String) async {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty, !Task.isCancelled else { return }

        isProcessing = true
        defer { isProcessing = false }
        do {
            let draftID = try await capture.process(flow: flow, transcript: trimmedTranscript)
            guard !Task.isCancelled else { return }
            savedDraftID = draftID
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }
}
