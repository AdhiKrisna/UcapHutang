import SwiftUI

struct CatatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var scaledControlDiameter: CGFloat = 220
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
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: AppSpacing.xLarge) {
                    transcriptInput

                    Spacer(minLength: AppSpacing.small)

                    Button {
                        Task { await viewModel.handleMicTap() }
                    } label: {
                        recordingControl
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isProcessing)
                    .accessibilityLabel(viewModel.recordButtonLabel)
                    .accessibilityValue(viewModel.stageHeadline)

                    Spacer(minLength: AppSpacing.small)

                    speechHints

                    VStack(spacing: AppSpacing.medium) {
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
                            .padding(AppSpacing.medium)
                            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                        }

                        if !viewModel.speech.usesOnDeviceRecognition {
                            Text("Ucapan diproses oleh server Apple.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: 340)
                }
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
                .padding(.horizontal, AppSpacing.xLarge)
                .padding(.vertical, AppSpacing.large)
            }
        }
        .background(AppColors.background)
        .safeAreaInset(edge: .bottom) {
            if viewModel.isListening {
                Button {
                    Task { await viewModel.restartRecording() }
                } label: {
                    Label("Ulangi", systemImage: "arrow.counterclockwise")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.horizontal, 24)
                        .frame(minHeight: 44)
                        .background(AppColors.surface, in: Capsule())
                        .overlay(Capsule().stroke(AppColors.border))
                        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
                }
                .padding(.bottom, AppSpacing.large)
            }
        }
        .navigationTitle(flow == .personal ? "Catat Utang/Piutang" : "Catat Split Bill")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            AppStoreNavigationTitle(title: flow == .personal ? "Catat Utang/Piutang" : "Catat Split Bill")
        }
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
            guard let draftID else { return }
            router.openReview(draftID: draftID)
            AccessibilityNotification.Announcement("Draft siap ditinjau").post()
            dismiss()
        }
    }

    private var transcriptInput: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            if !viewModel.isListening {
                Text("KETIK MANUAL")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(flow.accentColor)
            }

            HStack(alignment: .bottom, spacing: AppSpacing.small) {
                if viewModel.isListening {
                    Text(viewModel.speech.liveTranscript.isEmpty ? "Mulai berbicara…" : viewModel.speech.liveTranscript)
                        .font(.body)
                        .foregroundStyle(viewModel.speech.liveTranscript.isEmpty ? AppColors.textSecondary : AppColors.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: viewModel.speech.liveTranscript)
                } else {
                    TextField(
                        flow == .personal ? "Ceritakan utang atau piutangmu" : "Ceritakan pembagian tagihannya",
                        text: $viewModel.manualTranscript,
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                    .submitLabel(.send)
                    .disabled(viewModel.isProcessing)
                    .onSubmit { Task { await viewModel.submitManualTranscript() } }

                    Button {
                        Task { await viewModel.submitManualTranscript() }
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.body.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(flow.accentColor, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canSubmitManualTranscript)
                    .opacity(viewModel.canSubmitManualTranscript ? 1 : 0.35)
                    .accessibilityLabel("Kirim catatan manual")
                }
            }
            .padding(AppSpacing.medium)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .stroke(viewModel.isListening ? AppColors.border : flow.accentColor.opacity(0.32), lineWidth: 1)
            )
        }
    }

    private var speechHints: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Label("Contoh ucapan", systemImage: "quote.bubble.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(flow.accentColor)

            ForEach(Array(flow.speechExamples.enumerated()), id: \.offset) { index, example in
                VStack(alignment: .leading, spacing: 3) {
                    if flow == .personal {
                        Text(index == 0 ? "KAMU YANG BERUTANG" : "ORANG LAIN BERUTANG")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(index == 0 ? AppColors.debt : AppColors.receivable)
                    }
                    Text("“\(example)”")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textPrimary)
                        .italic()
                }
                if index < flow.speechExamples.count - 1 { Divider() }
            }
        }
        .padding(.horizontal, AppSpacing.small)
        .frame(maxWidth: 340, alignment: .leading)
    }

    private var recordingControl: some View {
        ZStack {
            if viewModel.isListening {
                ListeningMicAura(
                    speech: viewModel.speech,
                    accentColor: flow.accentColor,
                    diameter: controlDiameter,
                    reduceMotion: reduceMotion
                )
                SonarPingRing(
                    speech: viewModel.speech,
                    accentColor: flow.accentColor,
                    diameter: controlDiameter,
                    reduceMotion: reduceMotion
                )
            }
            Circle()
                .fill(flow.accentColor.opacity(viewModel.isListening ? 0.14 : 0.08))
            Circle()
                .stroke(flow.accentColor.opacity(0.7), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [7, 7]))
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
                .foregroundStyle(viewModel.isListening ? flow.accentColor : AppColors.textPrimary)
                .padding(24)
            }
        }
        .frame(width: controlDiameter, height: controlDiameter)
        .contentShape(Circle())
    }
}

private struct ListeningMicAura: View {
    let speech: any SpeechTranscribing
    let accentColor: Color
    let diameter: CGFloat
    let reduceMotion: Bool

    var body: some View {
        let level = CGFloat(speech.audioLevel)
        Circle()
            .fill(
                RadialGradient(
                    colors: [accentColor.opacity(0.30), accentColor.opacity(0.10), .clear],
                    center: .center,
                    startRadius: diameter * 0.12,
                    endRadius: diameter * 0.46
                )
            )
            .frame(width: diameter * (0.60 + level * 0.18), height: diameter * (0.60 + level * 0.18))
            .animation(reduceMotion ? nil : .spring(response: 0.18, dampingFraction: 0.55), value: level)
            .accessibilityHidden(true)
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

#Preview("Catat View - Personal") {
    let repo = InMemoryTransactionRepository()
    let contacts = SystemContactsProvider()
    let extraction = QwenDraftExtractionService()
    let reminderSettings = UserDefaultsReminderSettingsStore()
    let scheduler = ReviewReminderScheduler(center: SystemNotificationCenterClient(), settingsStore: reminderSettings, repository: repo)
    let container = AppContainer(
        repository: repo,
        extraction: extraction,
        contacts: contacts,
        reminderSettings: reminderSettings,
        reminderScheduler: scheduler
    )
    NavigationStack {
        CatatView(flow: .personal, container: container)
    }
}

#Preview("Catat View - Split Bill") {
    let repo = InMemoryTransactionRepository()
    let contacts = SystemContactsProvider()
    let extraction = QwenDraftExtractionService()
    let reminderSettings = UserDefaultsReminderSettingsStore()
    let scheduler = ReviewReminderScheduler(center: SystemNotificationCenterClient(), settingsStore: reminderSettings, repository: repo)
    let container = AppContainer(
        repository: repo,
        extraction: extraction,
        contacts: contacts,
        reminderSettings: reminderSettings,
        reminderScheduler: scheduler
    )
    NavigationStack {
        CatatView(flow: .splitBill, container: container)
    }
}
