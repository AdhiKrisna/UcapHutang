import SwiftUI

struct CatatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var scaledControlDiameter: CGFloat = 250
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

    /// Grows with Dynamic Type but never wider than a phone screen allows.
    private var controlDiameter: CGFloat {
        min(scaledControlDiameter, 320)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Button {
                    Task { await viewModel.handleMicTap() }
                } label: {
                    recordingControl
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isProcessing)
                .accessibilityLabel(viewModel.recordButtonLabel)
                .accessibilityValue(viewModel.stageHeadline)

                if viewModel.isListening {
                    Text(viewModel.speech.liveTranscript.isEmpty ? viewModel.stageHeadline : viewModel.speech.liveTranscript)
                        .font(viewModel.speech.liveTranscript.isEmpty ? .body : .body.weight(.medium))
                        .foregroundStyle(viewModel.speech.liveTranscript.isEmpty ? AppColors.textSecondary : AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: viewModel.speech.liveTranscript)
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

                if !viewModel.speech.usesOnDeviceRecognition {
                    Text("Ucapan diproses oleh server Apple.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.isListening {
                Button("Ulangi") {
                    Task { await viewModel.restartRecording() }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, 28)
                .frame(minHeight: 44)
                .background(AppColors.surface, in: Capsule())
                .overlay(Capsule().stroke(AppColors.border))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle(flow.title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { viewModel.cancel() }
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

    private var recordingControl: some View {
        ZStack {
            if viewModel.isListening {
                ListeningMicAura(speech: viewModel.speech, diameter: controlDiameter, reduceMotion: reduceMotion)
            }
            Circle()
                .stroke(
                    AppColors.textSecondary.opacity(0.65),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [7, 7])
                )
            if viewModel.isProcessing || viewModel.speech.state == .finalizing {
                ProgressView()
                    .controlSize(.large)
                    .tint(AppColors.textPrimary)
            } else {
                VStack(spacing: 12) {
                    Group {
                        if viewModel.isListening {
                            SpeakingMicIcon(reduceMotion: reduceMotion)
                        } else {
                            Image(systemName: "mic.fill")
                                .font(.largeTitle.weight(.bold))
                        }
                    }
                    .accessibilityHidden(true)
                    Text(viewModel.isListening ? "Tekan untuk\nberhenti" : "Tekan untuk catat\nvia suara")
                        .font(.title3.weight(.bold))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(AppColors.textPrimary)
                .padding(24)
            }
        }
        .frame(width: controlDiameter, height: controlDiameter)
        .contentShape(Circle())
    }

    private var tipText: String {
        flow == .personal
            ? "Dito pinjam 50 ribu buat beli bensin"
            : "Split bill makan 100 ribu sama Satria dan Arif bagi rata"
    }
}

/// Glow and rings shown while listening (from PR #3).
/// Reads `audioLevel` here so only this view redraws on every audio buffer.
private struct ListeningMicAura: View {
    let speech: any SpeechTranscribing
    let diameter: CGFloat
    let reduceMotion: Bool

    @State private var isRinging = false

    /// PR #3 tuned these sizes for a 250 pt control; scale them with the Dynamic Type control size.
    private var scale: CGFloat { diameter / 250 }

    var body: some View {
        let level = CGFloat(speech.audioLevel)
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [AppColors.accent.opacity(0.24), Color.purple.opacity(0.10), .clear],
                        center: .center,
                        startRadius: 30 * scale,
                        endRadius: 82 * scale
                    )
                )
                .frame(width: (136 + level * 46) * scale, height: (136 + level * 46) * scale)
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
                    .frame(width: 108 * scale, height: 108 * scale)
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
        .frame(width: 176 * scale, height: 176 * scale)
        .accessibilityHidden(true)
        .onAppear { isRinging = true }
    }
}

/// Mic icon that wobbles while listening (from PR #3). Still when Reduce Motion is on.
private struct SpeakingMicIcon: View {
    let reduceMotion: Bool

    @State private var isSpeaking = false

    var body: some View {
        Image(systemName: "mic.fill")
            .font(.largeTitle.weight(.semibold))
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
