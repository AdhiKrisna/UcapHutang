import SwiftUI

struct CatatView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CatatViewModel

    let flow: CaptureFlow

    init(flow: CaptureFlow, container: AppContainer) {
        self.flow = flow
        _viewModel = State(initialValue: CatatViewModel(flow: flow, container: container))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    Button { viewModel.handleMicTap() } label: {
                        recordingControl
                    }
                    .disabled(viewModel.isProcessing)

                    if isListening {
                        Button("Ulangi") { viewModel.restartRecording() }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(AppColors.surface)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppColors.border))

                        Text(viewModel.liveTranscript.isEmpty ? viewModel.stageHeadline : viewModel.liveTranscript)
                            .font(viewModel.liveTranscript.isEmpty ? .body : .body.weight(.medium))
                            .foregroundStyle(viewModel.liveTranscript.isEmpty ? AppColors.textSecondary : AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                            .animation(.easeInOut(duration: 0.2), value: viewModel.liveTranscript)
                    } else if !viewModel.isProcessing {
                        Text("Tip: \(tipText)")
                            .font(.body)
                            .foregroundStyle(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 24)
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
            .onChange(of: viewModel.speechRecognizer.state) { _, state in
                viewModel.handleSpeechStateChange(state)
            }
            // Temporary until P4 replaces this with "close + banner".
            .navigationDestination(item: $viewModel.createdDraftID) { draftID in
                ReviewDetailView(
                    draftID: draftID,
                    repository: viewModel.container.repository,
                    contacts: viewModel.container.contacts
                )
            }
        }
    }

    private var isListening: Bool {
        viewModel.isStartingRecording || viewModel.speechRecognizer.isRecording
    }

    private var recordingControl: some View {
        ZStack {
            Circle()
                .stroke(
                    AppColors.textSecondary.opacity(0.65),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [7, 7])
                )
                .frame(width: 250, height: 250)
            if viewModel.isProcessing || viewModel.speechRecognizer.state == .finalizing {
                ProgressView().tint(AppColors.textPrimary).scaleEffect(1.3)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: isListening ? "stop.fill" : "play.fill")
                        .font(.system(size: 34, weight: .bold))
                    Text(isListening ? "Tekan untuk\nberhenti" : "Tekan untuk catat\nvia suara")
                        .font(.title3.weight(.bold))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(AppColors.textPrimary)
            }
        }
        .frame(width: 250, height: 250)
    }

    private var tipText: String {
        flow == .personal
            ? "Dito pinjam 50 ribu buat beli bensin"
            : "Split bill makan 100 ribu sama Satria dan Arif bagi rata"
    }
}
