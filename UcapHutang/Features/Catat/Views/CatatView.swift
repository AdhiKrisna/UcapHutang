import SwiftUI

struct CatatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var viewModel: CatatViewModel
    private let router: AppRouter

    let flow: CaptureFlow

    init(flow: CaptureFlow, container: AppContainer) {
        self.flow = flow
        self.router = container.router
        _viewModel = State(initialValue: CatatViewModel(
            flow: flow,
            speech: container.makeSpeechTranscriber(),
            capture: container.capture
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    Button {
                        Task { await viewModel.handleMicTap() }
                    } label: {
                        recordingControl
                    }
                    .disabled(viewModel.isProcessing)
                    .accessibilityLabel(viewModel.recordButtonLabel)
                    .accessibilityValue(viewModel.stageHeadline)

                    if viewModel.isListening {
                        Button("Ulangi") {
                            Task { await viewModel.restartRecording() }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(AppColors.surface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppColors.border))

                        Text(viewModel.speech.liveTranscript.isEmpty ? viewModel.stageHeadline : viewModel.speech.liveTranscript)
                            .font(viewModel.speech.liveTranscript.isEmpty ? .body : .body.weight(.medium))
                            .foregroundStyle(viewModel.speech.liveTranscript.isEmpty ? AppColors.textSecondary : AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                            .animation(.easeInOut(duration: 0.2), value: viewModel.speech.liveTranscript)
                    } else if !viewModel.isProcessing {
                        Text("Tip: \(tipText)")
                            .font(.body)
                            .foregroundStyle(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                    }

                    if let permissionMessage = viewModel.permissionMessage {
                        VStack(spacing: 8) {
                            Text(permissionMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Buka Pengaturan") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    openURL(url)
                                }
                            }
                            .buttonStyle(.bordered)
                            .frame(minHeight: 44)
                        }
                        .frame(maxWidth: 300)
                    }
                }

                Spacer()

                if !viewModel.speech.usesOnDeviceRecognition {
                    Text("Ucapan diproses oleh server Apple.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 12)
                }
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
            .onChange(of: viewModel.speech.state) { _, state in
                viewModel.handleSpeechStateChange(state)
            }
            .onChange(of: viewModel.savedDraftID) { _, draftID in
                guard draftID != nil else { return }
                router.showSavedToReviewBanner()
                AccessibilityNotification.Announcement("Tersimpan ke Review").post()
                dismiss()
            }
        }
    }

    private var recordingControl: some View {
        ZStack {
            Circle()
                .stroke(
                    AppColors.textSecondary.opacity(0.65),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [7, 7])
                )
                .frame(width: 250, height: 250)
            if viewModel.isProcessing || viewModel.speech.state == .finalizing {
                ProgressView().tint(AppColors.textPrimary).scaleEffect(1.3)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: viewModel.isListening ? "stop.fill" : "play.fill")
                        .font(.system(size: 34, weight: .bold))
                    Text(viewModel.isListening ? "Tekan untuk\nberhenti" : "Tekan untuk catat\nvia suara")
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
