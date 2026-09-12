import SwiftUI

struct CatatView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CatatViewModel

    let flow: CaptureFlow

    init(flow: CaptureFlow, container: AppContainer) {
        self.flow = flow
        _viewModel = StateObject(wrappedValue: CatatViewModel(flow: flow, container: container))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.large) {
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Label("UCAPANMU", systemImage: "quote.bubble.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.textSecondary)
                    Text(viewModel.liveTranscript.isEmpty ? exampleText : viewModel.liveTranscript)
                        .font(.body)
                        .foregroundStyle(viewModel.liveTranscript.isEmpty ? AppColors.textSecondary : AppColors.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
                        .padding(AppSpacing.medium)
                        .background(AppColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                        .overlay(RoundedRectangle(cornerRadius: AppRadius.medium)
                            .stroke(viewModel.speechRecognizer.isRecording ? AppColors.accent : .clear, lineWidth: 1.5))
                }
                .padding(.horizontal)

                Spacer()

                VStack(spacing: AppSpacing.medium) {
                    Button { viewModel.handleMicTap() } label: {
                        ZStack {
                            Circle()
                                .fill(viewModel.micButtonGradient)
                                .frame(width: 110, height: 110)
                                .shadow(color: AppColors.accent.opacity(0.3), radius: 16, y: 6)
                            if viewModel.isProcessing || viewModel.speechRecognizer.state == .finalizing {
                                ProgressView().tint(.white).scaleEffect(1.4)
                            } else {
                                Image(systemName: viewModel.speechRecognizer.isRecording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 40, weight: .bold)).foregroundStyle(.white)
                            }
                        }
                    }
                    .disabled(viewModel.isProcessing)
                    Text(viewModel.stageHeadline).font(.title3.weight(.bold))
                    if viewModel.speechRecognizer.isRecording {
                        Text("Tap lingkaran untuk berhenti & proses")
                            .font(.caption).foregroundStyle(AppColors.textSecondary)
                    }
                }

                Spacer()

                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Text("PANDUAN BICARA").font(.caption.weight(.bold)).foregroundStyle(AppColors.textSecondary)
                    Text(flow == .personal
                         ? "• Sebutkan 1 orang, nominal, keperluan, dan siapa yang berutang."
                         : "• Sebutkan teman-teman yang ikut patungan dan nominal/total.")
                        .font(.caption)
                    Text(flow == .personal
                         ? "• Contoh: \"Dito pinjam 50 ribu buat beli bensin\""
                         : "• Contoh: \"Split bill makan gacoan 100 ribu sama Satria dan Arif bagi rata\"")
                        .font(.caption).foregroundStyle(flow == .personal ? AppColors.accent : AppColors.split)
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
            .onDisappear { viewModel.cancel() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { viewModel.cancel(); dismiss() }
                }
            }
            .alert("Gagal Memproses", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) { Button("OK", role: .cancel) {} } message: {
                Text(viewModel.errorMessage ?? "Terjadi kesalahan.")
            }
            .onChange(of: viewModel.speechRecognizer.errorMessage) { _, message in
                if let message { viewModel.errorMessage = message }
            }
            .navigationDestination(item: $viewModel.createdDraftID) { draftID in
                ReviewDraftView(draftID: draftID, repository: viewModel.container.repository)
            }
        }
    }

    private var exampleText: String {
        flow == .personal
            ? "Contoh: \"Aku ngutang 20 ribu ke Budi buat beli kopi\""
            : "Contoh: \"Aku bayarin makan 90 ribu bareng Budi dan Doni bagi rata\""
    }
}
