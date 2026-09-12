import Foundation
import SwiftUI
import Combine

@MainActor
final class CatatViewModel: ObservableObject {
    let flow: CaptureFlow
    let onDraftCreated: (UUID) -> Void
    let container: AppContainer
    let speechRecognizer = SpeechRecognizer()

    @Published var liveTranscript = ""
    @Published var isProcessing = false
    @Published var errorMessage: String?

    private var activeProcessingID: UUID?
    private var processingTask: Task<Void, Never>?

    init(flow: CaptureFlow, onDraftCreated: @escaping (UUID) -> Void, container: AppContainer) {
        self.flow = flow
        self.onDraftCreated = onDraftCreated
        self.container = container
    }

    var micButtonGradient: LinearGradient {
        speechRecognizer.isRecording
            ? LinearGradient(colors: [.red, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(colors: [AppColors.accent, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var stageHeadline: String {
        if isProcessing { return "Menganalisis data..." }
        if speechRecognizer.state == .finalizing { return "Menyelesaikan transkrip..." }
        if speechRecognizer.isRecording { return "Mendengarkan..." }
        return "Tekan untuk catat suara"
    }

    func handleMicTap() {
        guard activeProcessingID == nil else { return }
        if speechRecognizer.isRecording {
            finishAndProcess()
        } else {
            liveTranscript = ""
            speechRecognizer.startRecording { [weak self] transcript in
                self?.liveTranscript = transcript
            }
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
                self.onDraftCreated(draft.id)
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
    }
}
