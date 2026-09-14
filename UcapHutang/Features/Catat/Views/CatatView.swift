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
            VStack(spacing: AppSpacing.xLarge) {
                // Header Flow Info
                VStack(spacing: 6) {
                    Text(flow.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)

                    Text(flow.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, AppSpacing.small)

                // Main Recording Button
                Button {
                    Task { await viewModel.handleMicTap() }
                } label: {
                    recordingControl
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isProcessing)
                .accessibilityLabel(viewModel.recordButtonLabel)
                .accessibilityValue(viewModel.stageHeadline)

                // Status Transcript or Tips Container
                VStack(spacing: AppSpacing.medium) {
                    if viewModel.isListening {
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(flow.accentColor)
                                    .frame(width: 8, height: 8)
                                    .opacity(reduceMotion ? 1 : 0.8)
                                Text("Mendengarkan...")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(flow.accentColor)
                            }

                            Text(viewModel.speech.liveTranscript.isEmpty ? "Mulai berbicara..." : viewModel.speech.liveTranscript)
                                .font(.body.weight(.medium))
                                .foregroundStyle(viewModel.speech.liveTranscript.isEmpty ? AppColors.textSecondary : AppColors.textPrimary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: viewModel.speech.liveTranscript)
                        }
                        .padding(AppSpacing.large)
                        .frame(maxWidth: .infinity)
                        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                                .stroke(flow.accentColor.opacity(0.3), lineWidth: 1)
                        )
                    } else if !viewModel.isProcessing {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Contoh Ucapan", systemImage: "lightbulb.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(flow.accentColor)

                            Text("“\(flow.exampleUcapan)”")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.textPrimary)
                                .italic()
                        }
                        .padding(AppSpacing.large)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                                .stroke(AppColors.border, lineWidth: 1)
                        )
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
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.xLarge)
            .padding(.vertical, AppSpacing.large)
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
        .navigationTitle("")
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
                SonarPingRing(
                    speech: viewModel.speech,
                    accentColor: flow.accentColor,
                    diameter: controlDiameter,
                    reduceMotion: reduceMotion
                )
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
