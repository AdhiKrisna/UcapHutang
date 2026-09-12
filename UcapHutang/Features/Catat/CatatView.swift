import SwiftUI

struct CatatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel: CatatViewModel

    let flow: CaptureFlow

    init(flow: CaptureFlow, container: AppContainer) {
        self.flow = flow
        _viewModel = StateObject(wrappedValue: CatatViewModel(flow: flow, container: container))
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
            .overlay(alignment: .bottom) {
                if isListening {
                    Button("Ulangi") { viewModel.restartRecording() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(AppColors.surface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppColors.border))
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                        .padding(.bottom, 20)
                }
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
            .onChange(of: viewModel.speechRecognizer.state) { _, state in
                viewModel.handleSpeechStateChange(state)
            }
            .navigationDestination(item: $viewModel.createdDraftID) { draftID in
                ReviewDraftView(draftID: draftID, repository: viewModel.container.repository)
            }
        }
    }

    private var isListening: Bool {
        viewModel.isStartingRecording || viewModel.speechRecognizer.isRecording
    }

    private var recordingControl: some View {
        ZStack {
            if isListening {
                ListeningMicAura(
                    level: viewModel.speechRecognizer.audioLevel,
                    reduceMotion: reduceMotion
                )
            }
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
                    if isListening {
                        SpeakingMicIcon(reduceMotion: reduceMotion)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 34, weight: .bold))
                    }
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

private struct ListeningMicAura: View {
    let level: Float
    let reduceMotion: Bool

    @State private var isRinging = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [AppColors.accent.opacity(0.24), Color.purple.opacity(0.10), .clear],
                        center: .center,
                        startRadius: 30,
                        endRadius: 82
                    )
                )
                .frame(width: 136 + CGFloat(level) * 46, height: 136 + CGFloat(level) * 46)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.18, dampingFraction: 0.55),
                    value: level
                )

            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [AppColors.accent.opacity(0.85), Color.purple.opacity(0.42)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: 108, height: 108)
                    .scaleEffect(reduceMotion ? 1.12 : (isRinging ? 1.72 : 0.92))
                    .opacity(reduceMotion ? 0.42 : (isRinging ? 0 : 0.68))
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeOut(duration: 1.6)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.4),
                        value: isRinging
                    )
            }
        }
        .frame(width: 176, height: 176)
        .onAppear { isRinging = true }
    }
}

private struct SpeakingMicIcon: View {
    let reduceMotion: Bool

    @State private var isSpeaking = false

    var body: some View {
        Image(systemName: "mic.fill")
            .font(.system(size: 36, weight: .semibold))
            .foregroundStyle(AppColors.textPrimary)
            .rotationEffect(.degrees(reduceMotion ? 0 : (isSpeaking ? 4 : -4)))
            .scaleEffect(reduceMotion ? 1 : (isSpeaking ? 1.08 : 0.96))
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.16).repeatForever(autoreverses: true),
                value: isSpeaking
            )
            .onAppear { isSpeaking = true }
    }
}
