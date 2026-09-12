import Foundation
import Observation

@Observable
final class CatatViewModel {
    let flow: CaptureFlow
    var createdDraftID: UUID?
    let container: AppContainer
    let speechRecognizer = SpeechRecognizer()

    var liveTranscript = ""
    var isProcessing = false
    var errorMessage: String?
    private(set) var isStartingRecording = false

    @ObservationIgnored private var activeProcessingID: UUID?
    @ObservationIgnored private var processingTask: Task<Void, Never>?

    init(flow: CaptureFlow, container: AppContainer) {
        self.flow = flow
        self.container = container
    }

    var stageHeadline: String {
        if isProcessing { return "Menganalisis data..." }
        if speechRecognizer.state == .finalizing { return "Menyelesaikan transkrip..." }
        if isStartingRecording || speechRecognizer.isRecording { return "Mendengarkan..." }
        return ""
    }

    func handleMicTap() {
        guard activeProcessingID == nil else { return }
        if speechRecognizer.isRecording {
            finishAndProcess()
        } else {
            startRecording()
        }
    }

    func restartRecording() {
        guard activeProcessingID == nil else { return }
        speechRecognizer.cancelRecording()
        startRecording()
    }

    func handleSpeechStateChange(_ state: SpeechRecognizerState) {
        switch state {
        case .listening:
            isStartingRecording = false
        case .failed, .idle:
            if !isProcessing { isStartingRecording = false }
        case .finalizing:
            break
        }
    }

    private func startRecording() {
        liveTranscript = ""
        isStartingRecording = true
        speechRecognizer.startRecording { [weak self] transcript in
            self?.liveTranscript = transcript
        }
    }

    private func finishAndProcess() {
        guard activeProcessingID == nil else { return }
        let requestID = UUID()
        activeProcessingID = requestID
        isProcessing = true
        processingTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.activeProcessingID == requestID {
                    self.activeProcessingID = nil
                    self.processingTask = nil
                    self.isProcessing = false
                }
            }
            let finalTranscript = await self.speechRecognizer.finishRecording()
            guard !Task.isCancelled, self.activeProcessingID == requestID else { return }
            let clean = finalTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? self.liveTranscript : finalTranscript
            guard !clean.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                self.errorMessage = "Suara tidak terdeteksi. Silakan coba lagi."
                return
            }
            do {
                let draft = try await self.container.extractionService.extract(DraftExtractionRequest(flow: self.flow, transcript: clean))
                try Task.checkCancellation()
                try await self.container.repository.saveDraft(draft)
                try Task.checkCancellation()
                self.createdDraftID = draft.id
            } catch {
                guard !Task.isCancelled else { return }
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func cancel() {
        speechRecognizer.cancelRecording()
        processingTask?.cancel()
        processingTask = nil
        activeProcessingID = nil
        isStartingRecording = false
    }
}
