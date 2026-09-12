import SwiftUI
import Combine

struct CaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var container: AppContainer
    @StateObject private var speechRecognizer = SpeechRecognizer()

    let flow: CaptureFlow
    let onDraftCreated: (UUID) -> Void

    @State private var liveTranscript: String = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var activeProcessingID: UUID?
    @State private var processingTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.large) {
                // Top Transcript Stage
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Label("UCAPANMU", systemImage: "quote.bubble.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.textSecondary)

                    Text(liveTranscript.isEmpty
                         ? (flow == .personal
                            ? "Contoh: \"Aku ngutang 20 ribu ke Budi buat beli kopi\""
                            : "Contoh: \"Aku bayarin makan 90 ribu bareng Budi dan Doni bagi rata\"")
                         : liveTranscript)
                        .font(.body)
                        .foregroundStyle(liveTranscript.isEmpty ? AppColors.textSecondary : AppColors.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
                        .padding(AppSpacing.medium)
                        .background(AppColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .stroke(speechRecognizer.isRecording ? AppColors.accent : Color.clear, lineWidth: 1.5)
                        )
                }
                .padding(.horizontal)

                Spacer()

                // Center Voice Control
                VStack(spacing: AppSpacing.medium) {
                    Button {
                        handleMicTap()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(micButtonGradient)
                                .frame(width: 110, height: 110)
                                .shadow(color: AppColors.accent.opacity(0.3), radius: 16, y: 6)

                            if isProcessing || speechRecognizer.state == .finalizing {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(1.4)
                            } else {
                                Image(systemName: speechRecognizer.isRecording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .disabled(isProcessing)

                    Text(stageHeadline)
                        .font(.title3.weight(.bold))

                    if speechRecognizer.isRecording {
                        Text("Tap lingkaran untuk berhenti & proses")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

                Spacer()

                // Guide Prompt Chips
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Text("PANDUAN BICARA")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.textSecondary)

                    if flow == .personal {
                        Text("• Sebutkan 1 orang, nominal, keperluan, dan siapa yang berutang.")
                            .font(.caption)
                        Text("• Contoh: \"Dito pinjam 50 ribu buat beli bensin\"")
                            .font(.caption)
                            .foregroundStyle(AppColors.accent)
                    } else {
                        Text("• Sebutkan teman-teman yang ikut patungan dan nominal/total.")
                            .font(.caption)
                        Text("• Contoh: \"Split bill makan gacoan 100 ribu sama Satria dan Arif bagi rata\"")
                            .font(.caption)
                            .foregroundStyle(AppColors.split)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(AppColors.surface.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                .padding(.horizontal)
                .padding(.bottom, AppSpacing.medium)
            }
            .navigationTitle(flow.title)
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear {
                speechRecognizer.cancelRecording()
                processingTask?.cancel()
                processingTask = nil
                activeProcessingID = nil
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") {
                        speechRecognizer.cancelRecording()
                        dismiss()
                    }
                }
            }
            .alert("Gagal Memproses", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Terjadi kesalahan.")
            }
            .onChange(of: speechRecognizer.errorMessage) { _, message in
                if let message { errorMessage = message }
            }
        }
    }

    private var micButtonGradient: LinearGradient {
        if speechRecognizer.isRecording {
            return LinearGradient(colors: [Color.red, Color.pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            return LinearGradient(colors: [AppColors.accent, Color.indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var stageHeadline: String {
        if isProcessing { return "Menganalisis data..." }
        if speechRecognizer.state == .finalizing { return "Menyelesaikan transkrip..." }
        if speechRecognizer.isRecording { return "Mendengarkan..." }
        return "Tekan untuk catat suara"
    }

    private func handleMicTap() {
        guard activeProcessingID == nil else { return }
        if speechRecognizer.isRecording {
            finishAndProcess()
        } else {
            liveTranscript = ""
            speechRecognizer.startRecording { transcript in
                self.liveTranscript = transcript
            }
        }
    }

    private func finishAndProcess() {
        guard activeProcessingID == nil else { return }
        let requestID = UUID()
        activeProcessingID = requestID
        isProcessing = true
        processingTask = Task {
            defer {
                if activeProcessingID == requestID {
                    activeProcessingID = nil
                    processingTask = nil
                    isProcessing = false
                }
            }
            let finalTranscript = await speechRecognizer.finishRecording()
            guard !Task.isCancelled, activeProcessingID == requestID else { return }
            let clean = finalTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? liveTranscript : finalTranscript
            guard !clean.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                await MainActor.run {
                    self.errorMessage = "Suara tidak terdeteksi. Silakan coba lagi."
                }
                return
            }

            do {
                let draft = try await container.extractionService.extract(
                    DraftExtractionRequest(flow: flow, transcript: clean)
                )
                try Task.checkCancellation()
                try await container.repository.saveDraft(draft)
                try Task.checkCancellation()
                await MainActor.run {
                    dismiss()
                    onDraftCreated(draft.id)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
