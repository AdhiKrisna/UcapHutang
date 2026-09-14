# Catat UI/UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the Catat flow chooser as example-driven tiles (no visible model-readiness text) and replace the recording screen's busy aura/rings animation with a single flow-colored "sonar ping" that fires once per loud moment, while extending each flow's accent color across the whole recording screen.

**Architecture:** `CaptureFlow` (Domain) gains `icon`/`subtitle`/`exampleUcapan`; a Core extension adds `accentColor` (kept out of Domain to preserve its SwiftUI-free layering). A new pure `SonarPingTrigger` decides *when* to fire, unit-tested with no SwiftUI dependency; a new `SonarPingRing` view uses it to drive a `PhaseAnimator`-based one-shot ring animation. `CatatFlowChooserView` and `CatatView` are rewritten to consume this shared metadata instead of their own local, duplicated color/copy logic.

**Tech Stack:** SwiftUI (iOS 26.5+), `PhaseAnimator` (iOS 17+, available on this project's deployment target), XCTest.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-09-14-catat-ui-ux-design.md`. Every requirement in it is in scope; nothing outside it (the post-recording transition, the voice→LLM→draft pipeline, `RootTabView` wiring) changes.
- No new colors: `accentColor` reuses the existing `AppColors.accent` (blue, `.personal`) and `AppColors.split` (orange, `.splitBill`) tokens.
- Domain layer (`UcapHutang/Domain/**`) never imports SwiftUI — this project's existing convention. `accentColor` therefore lives in `Core/Extensions/`, not alongside `icon`/`subtitle`/`exampleUcapan` in `Domain/Models/TransactionModels.swift`.
- The model-readiness gate (`.disabled(readiness != .ready)`) stays exactly as it behaves today. No status text, banner, or caption may be added anywhere on the chooser screen.
- `SpeakingMicIcon`'s wobble while listening is kept unchanged — do not delete or modify that struct.
- Reduce Motion: every new animation must have a reduced-motion form that still shows *something* (a brief, fixed-size appearance), never nothing.
- Test command (run after every task):
  `xcodebuild test -project UcapHutang.xcodeproj -scheme UcapHutang -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | grep -E "Test Case '.*' (passed|failed)|error:|Executed [0-9]+ tests|TEST SUCCEEDED|TEST FAILED"`
  Single class: append `-only-testing:UcapHutangTests/<ClassName>` before `2>&1`.
- Build-only command (for SwiftUI-only tasks with no new XCTest):
  `xcodebuild build -project UcapHutang.xcodeproj -scheme UcapHutang -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"`
- Baseline before this plan: **134 tests passing.** Expected after each task: Task 1 → 136, Task 2 → 140, Tasks 3–5 → 140 (build-verified, no new tests), Task 6 → 140 confirmed.
- Never stage `.xcede/` or `xcede.yml`. Explicit `git add` paths only. Do not touch `UcapHutang.xcodeproj/project.pbxproj`.

---

## File Map

| File | Task | Change |
|---|---|---|
| `UcapHutang/Domain/Models/TransactionModels.swift` | 1 | Add `icon`, `subtitle`, `exampleUcapan` to `CaptureFlow` |
| `UcapHutang/Core/Extensions/CaptureFlow+AccentColor.swift` | 1 | Create — `accentColor` |
| `UcapHutangTests/CaptureFlowMetadataTests.swift` | 1 | Create |
| `UcapHutang/Core/Utilities/SonarPingTrigger.swift` | 2 | Create |
| `UcapHutangTests/SonarPingTriggerTests.swift` | 2 | Create |
| `UcapHutang/Features/Catat/Components/SonarPingRing.swift` | 3 | Create |
| `UcapHutang/Features/Catat/Views/CatatFlowChooserView.swift` | 4 | Full replacement |
| `UcapHutang/Features/Catat/Views/CatatView.swift` | 5 | Full replacement |
| `docs/superpowers/specs/2026-09-12-voice-draft-remediation-design.md` | 6 | Amend §7.4 (one line) |

---

### Task 1: `CaptureFlow` metadata (icon, subtitle, example ucapan, accent color)

**Files:**
- Modify: `UcapHutang/Domain/Models/TransactionModels.swift`
- Create: `UcapHutang/Core/Extensions/CaptureFlow+AccentColor.swift`
- Create: `UcapHutangTests/CaptureFlowMetadataTests.swift`

**Interfaces:**
- Consumes: nothing new — `CaptureFlow` already exists with `.personal`/`.splitBill` cases and a `title` property.
- Produces: `CaptureFlow.icon: String`, `.subtitle: String`, `.exampleUcapan: String` (Domain), `.accentColor: Color` (Core extension). Tasks 3–5 read all four.

- [ ] **Step 1: Write the failing tests**

Create `UcapHutangTests/CaptureFlowMetadataTests.swift`:

```swift
import XCTest
import SwiftUI
@testable import UcapHutang

final class CaptureFlowMetadataTests: XCTestCase {
    func testPersonalFlowMetadata() {
        XCTAssertEqual(CaptureFlow.personal.icon, "person.2")
        XCTAssertEqual(CaptureFlow.personal.subtitle, "Catat utang atau piutang personal dengan satu orang")
        XCTAssertEqual(CaptureFlow.personal.exampleUcapan, "Dito pinjam 50 ribu buat beli bensin")
        XCTAssertEqual(CaptureFlow.personal.accentColor, AppColors.accent)
    }

    func testSplitBillFlowMetadata() {
        XCTAssertEqual(CaptureFlow.splitBill.icon, "person.3.fill")
        XCTAssertEqual(CaptureFlow.splitBill.subtitle, "Catat patungan/bagi rata makan atau belanja bareng")
        XCTAssertEqual(CaptureFlow.splitBill.exampleUcapan, "Split bill makan 100 ribu sama Satria dan Arif bagi rata")
        XCTAssertEqual(CaptureFlow.splitBill.accentColor, AppColors.split)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the test command with `-only-testing:UcapHutangTests/CaptureFlowMetadataTests`.
Expected: build FAILS with `value of type 'CaptureFlow' has no member 'icon'` (and `subtitle`, `exampleUcapan`, `accentColor`).

- [ ] **Step 3: Add the Domain metadata**

In `UcapHutang/Domain/Models/TransactionModels.swift`, the current `CaptureFlow` reads:

```swift
enum CaptureFlow: String, Codable, CaseIterable, Identifiable, Sendable {
    case personal
    case splitBill

    var id: String { rawValue }

    var title: String {
        switch self {
        case .personal: "Utang / Piutang"
        case .splitBill: "Split Bill"
        }
    }
}
```

Add these three properties directly after `title`, inside the same `enum CaptureFlow`:

```swift
    /// SF Symbol shown on the flow-chooser tile.
    var icon: String {
        switch self {
        case .personal: "person.2"
        case .splitBill: "person.3.fill"
        }
    }

    /// The recording screen's subtitle, directly under the flow title.
    var subtitle: String {
        switch self {
        case .personal: "Catat utang atau piutang personal dengan satu orang"
        case .splitBill: "Catat patungan/bagi rata makan atau belanja bareng"
        }
    }

    /// Baked into the chooser tile, and shown as the recording screen's "Contoh Ucapan".
    var exampleUcapan: String {
        switch self {
        case .personal: "Dito pinjam 50 ribu buat beli bensin"
        case .splitBill: "Split bill makan 100 ribu sama Satria dan Arif bagi rata"
        }
    }
```

- [ ] **Step 4: Add the Core accent-color extension**

Create `UcapHutang/Core/Extensions/CaptureFlow+AccentColor.swift`:

```swift
import SwiftUI

/// The color that identifies each capture flow throughout Catat: the chooser tile,
/// the recording screen's listening state, and the sonar ping.
///
/// Kept out of `Domain/Models/TransactionModels.swift` because Domain stays free of
/// SwiftUI imports in this project — this is the one Core-layer companion to that enum.
extension CaptureFlow {
    var accentColor: Color {
        switch self {
        case .personal: AppColors.accent
        case .splitBill: AppColors.split
        }
    }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run the same command as Step 2.
Expected: both test cases pass, `TEST SUCCEEDED`.

- [ ] **Step 6: Run the full suite**

Run the full test command (no `-only-testing`).
Expected: `Executed 136 tests, with 0 failures`, `TEST SUCCEEDED`.

- [ ] **Step 7: Commit**

```bash
git add UcapHutang/Domain/Models/TransactionModels.swift UcapHutang/Core/Extensions/CaptureFlow+AccentColor.swift UcapHutangTests/CaptureFlowMetadataTests.swift
git commit -m "feat: add CaptureFlow icon, subtitle, example ucapan and accent color"
```

---

### Task 2: `SonarPingTrigger` — pure fire/no-fire decision logic

**Files:**
- Create: `UcapHutang/Core/Utilities/SonarPingTrigger.swift`
- Create: `UcapHutangTests/SonarPingTriggerTests.swift`

**Interfaces:**
- Consumes: nothing (pure struct, no dependency on `SpeechTranscribing` or SwiftUI).
- Produces: `SonarPingTrigger` with `threshold: Float = 0.78`, `cooldown: TimeInterval = 0.7`, and `func shouldFire(level: Float, now: Date, lastFire: Date?) -> Bool`. Task 3 (`SonarPingRing`) calls this on every `audioLevel` change.

- [ ] **Step 1: Write the failing tests**

Create `UcapHutangTests/SonarPingTriggerTests.swift`:

```swift
import XCTest
@testable import UcapHutang

final class SonarPingTriggerTests: XCTestCase {
    private let trigger = SonarPingTrigger()
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testBelowThresholdNeverFires() {
        XCTAssertFalse(trigger.shouldFire(level: 0.5, now: now, lastFire: nil))
        XCTAssertFalse(trigger.shouldFire(level: 0.77, now: now, lastFire: now.addingTimeInterval(-10)))
    }

    func testAtOrAboveThresholdWithNoPriorFireFires() {
        XCTAssertTrue(trigger.shouldFire(level: 0.78, now: now, lastFire: nil))
        XCTAssertTrue(trigger.shouldFire(level: 0.95, now: now, lastFire: nil))
    }

    func testSecondCallInsideCooldownDoesNotFire() {
        let lastFire = now.addingTimeInterval(-0.5)
        XCTAssertFalse(trigger.shouldFire(level: 0.9, now: now, lastFire: lastFire))
    }

    func testCallAfterCooldownElapsedFiresAgain() {
        let lastFire = now.addingTimeInterval(-0.7)
        XCTAssertTrue(trigger.shouldFire(level: 0.9, now: now, lastFire: lastFire))
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the test command with `-only-testing:UcapHutangTests/SonarPingTriggerTests`.
Expected: build FAILS with `cannot find 'SonarPingTrigger' in scope`.

- [ ] **Step 3: Implement**

Create `UcapHutang/Core/Utilities/SonarPingTrigger.swift`:

```swift
import Foundation

/// Decides when the Catat recording screen's sonar-ping animation should fire, based
/// on smoothed microphone loudness (`SpeechTranscribing.audioLevel`, 0...1). Pure and
/// SwiftUI-free so it can be unit-tested directly.
struct SonarPingTrigger {
    var threshold: Float = 0.78
    var cooldown: TimeInterval = 0.7

    func shouldFire(level: Float, now: Date, lastFire: Date?) -> Bool {
        guard level >= threshold else { return false }
        guard let lastFire else { return true }
        return now.timeIntervalSince(lastFire) >= cooldown
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run the same command as Step 2.
Expected: all 4 test cases pass, `TEST SUCCEEDED`.

- [ ] **Step 5: Run the full suite**

Run the full test command.
Expected: `Executed 140 tests, with 0 failures`, `TEST SUCCEEDED`.

- [ ] **Step 6: Commit**

```bash
git add UcapHutang/Core/Utilities/SonarPingTrigger.swift UcapHutangTests/SonarPingTriggerTests.swift
git commit -m "feat: add SonarPingTrigger for the Catat recording animation"
```

---

### Task 3: `SonarPingRing` — the one-shot ping animation view

**Files:**
- Create: `UcapHutang/Features/Catat/Components/SonarPingRing.swift`

**Interfaces:**
- Consumes: `SonarPingTrigger` (Task 2), `CaptureFlow.accentColor` (Task 1, passed in as a plain `Color` so this view has no `CaptureFlow` dependency), `SpeechTranscribing.audioLevel` (already exists).
- Produces: `SonarPingRing(speech: any SpeechTranscribing, accentColor: Color, diameter: CGFloat, reduceMotion: Bool)`. Task 5 (`CatatView`) places this inside its `recordingControl` `ZStack`, replacing `ListeningMicAura`.

This is a pure SwiftUI view with no unit-testable logic of its own (the decision logic is already covered by `SonarPingTriggerTests`); its correctness is confirmed by building and by the manual QA in Task 6.

- [ ] **Step 1: Implement**

Create `UcapHutang/Features/Catat/Components/SonarPingRing.swift`:

```swift
import SwiftUI

/// A ring that appears once and, for a moment, fades out whenever the user's voice
/// gets loud enough — then disappears until the next peak. Replaces the old
/// always-on glow + triple pulsing rings with one clear, audio-reactive signal.
/// Color follows the active `CaptureFlow` via the `accentColor` passed in.
struct SonarPingRing: View {
    let speech: any SpeechTranscribing
    let accentColor: Color
    let diameter: CGFloat
    let reduceMotion: Bool

    @State private var trigger = 0
    @State private var lastFireDate: Date?
    private let pingTrigger = SonarPingTrigger()

    private enum Phase {
        case idle
        case start
        case expanded
    }

    /// Ring size at rest, proportional to the mic control's diameter (matches the
    /// ratio the previous rings used: 108pt on a 250pt control).
    private var baseRingDiameter: CGFloat { diameter * 0.432 }

    var body: some View {
        PhaseAnimator([Phase.idle, .start, .expanded, .idle], trigger: trigger) { phase, _ in
            Circle()
                .stroke(accentColor, lineWidth: 2.5)
                .frame(width: baseRingDiameter, height: baseRingDiameter)
                .scaleEffect(scale(for: phase))
                .opacity(opacity(for: phase))
        } animation: { phase in
            switch phase {
            case .idle, .start:
                nil
            case .expanded:
                .easeOut(duration: reduceMotion ? 0.3 : 0.9)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: speech.audioLevel) { _, level in
            let now = Date()
            guard pingTrigger.shouldFire(level: level, now: now, lastFire: lastFireDate) else { return }
            lastFireDate = now
            trigger += 1
        }
    }

    /// Reduce Motion never grows the ring — it only appears at a fixed size, per
    /// this project's Reduce Motion convention (show something, don't hide it).
    private func scale(for phase: Phase) -> CGFloat {
        switch phase {
        case .idle, .start: 1.0
        case .expanded: reduceMotion ? 1.0 : 2.1
        }
    }

    private func opacity(for phase: Phase) -> Double {
        switch phase {
        case .idle: 0
        case .start: 0.55
        case .expanded: 0
        }
    }
}
```

Why 4 phases: `.idle` (invisible) → `.start` (pops to visible at rest size, no animation — matches a ping *appearing*) → `.expanded` (animated over `0.9s`/`0.3s`: grows and fades to invisible) → `.idle` again (already invisible, so the snap-back is unnoticeable, and the sequence is ready for the next `trigger` change). `PhaseAnimator` replays this whole sequence once per `trigger` change, which is why `SonarPingTrigger` — not this view — owns the cooldown that prevents re-firing mid-animation.

- [ ] **Step 2: Build to verify it compiles**

Run the build-only command.
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add UcapHutang/Features/Catat/Components/SonarPingRing.swift
git commit -m "feat: add SonarPingRing, a one-shot audio-reactive ping animation"
```

---

### Task 4: Flow chooser — tiles with baked-in examples, no readiness text

**Files:**
- Modify (full replacement): `UcapHutang/Features/Catat/Views/CatatFlowChooserView.swift`

**Interfaces:**
- Consumes: `CaptureFlow.icon`/`.title`/`.exampleUcapan`/`.accentColor` (Task 1). `AppRouter`, `AppContainer`, `MLXQwenClient.readiness()`, `SavedToReviewBanner` — all unchanged, already used by this file today.
- Produces: no new public API. `CatatFlowChooserView(router:container:)`'s signature is unchanged, so `RootTabView` needs no changes.

- [ ] **Step 1: Replace the file**

Replace the whole content of `UcapHutang/Features/Catat/Views/CatatFlowChooserView.swift` with:

```swift
import SwiftUI

struct CatatFlowChooserView: View {
    let router: AppRouter
    let container: AppContainer
    @State private var selectedFlow: CaptureFlow?
    private let readiness = MLXQwenClient.readiness()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(router: AppRouter, container: AppContainer) {
        self.router = router
        self.container = container
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.large) {
                    Text("Pilih jenis pencatatan")
                        .font(.largeTitle.weight(.semibold))
                        .padding(.top, AppSpacing.small)

                    ForEach(CaptureFlow.allCases) { flow in
                        Button {
                            selectedFlow = flow
                        } label: {
                            FlowTile(flow: flow)
                        }
                        .buttonStyle(.plain)
                        .disabled(readiness != .ready)
                    }
                }
                .padding(AppSpacing.xLarge)
            }
            .navigationDestination(item: $selectedFlow) { flow in
                CatatView(flow: flow, container: container)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                if let bannerID = router.savedBannerID {
                    SavedToReviewBanner(
                        bannerID: bannerID,
                        onOpen: { router.openReviewFromBanner() },
                        onTimeout: { router.dismissSavedBanner() }
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
            .animation(reduceMotion ? nil : .default, value: router.savedBannerID)
        }
    }
}

/// One large tappable tile for a capture flow: icon, title, and a baked-in example
/// of how to phrase the recording. No readiness text is ever shown here — a disabled
/// tile (model not ready yet) looks and behaves like any other disabled control,
/// with no explanation. See §4 of the Catat UI/UX design spec.
private struct FlowTile: View {
    let flow: CaptureFlow

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(flow.accentColor.opacity(0.16))
                Image(systemName: flow.icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(flow.accentColor)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(flow.title)
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                Text("“\(flow.exampleUcapan)”")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AppSpacing.large)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(
            LinearGradient(
                colors: [flow.accentColor.opacity(0.10), flow.accentColor.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .stroke(flow.accentColor.opacity(0.18), lineWidth: 1)
        )
    }
}

#Preview("Catat Flow Chooser") {
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
    CatatFlowChooserView(router: container.router, container: container)
}
```

- [ ] **Step 2: Build to verify it compiles**

Run the build-only command.
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Run the full suite**

Run the full test command.
Expected: `Executed 140 tests, with 0 failures`, `TEST SUCCEEDED` (unchanged from Task 2 — this task touches no tested logic).

- [ ] **Step 4: Commit**

```bash
git add UcapHutang/Features/Catat/Views/CatatFlowChooserView.swift
git commit -m "feat: redesign the Catat flow chooser as example-driven tiles"
```

---

### Task 5: Recording screen — sonar ping + flow color everywhere

**Files:**
- Modify (full replacement): `UcapHutang/Features/Catat/Views/CatatView.swift`

**Interfaces:**
- Consumes: `CaptureFlow.subtitle`/`.exampleUcapan`/`.accentColor` (Task 1), `SonarPingRing` (Task 3). `CatatViewModel`, `SpeakingMicIcon` unchanged.
- Produces: no new public API. `CatatView(flow:container:)`'s signature is unchanged.

- [ ] **Step 1: Replace the file**

Replace the whole content of `UcapHutang/Features/Catat/Views/CatatView.swift` with:

```swift
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
```

Note what's gone: the `tipText`/`flowSubtitle` computed properties (replaced by `flow.exampleUcapan`/`flow.subtitle`) and the entire `private struct ListeningMicAura` (replaced by `SonarPingRing`, Task 3). `SpeakingMicIcon` is carried over byte-for-byte.

- [ ] **Step 2: Build to verify it compiles**

Run the build-only command.
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Run the full suite**

Run the full test command.
Expected: `Executed 140 tests, with 0 failures`, `TEST SUCCEEDED`.

- [ ] **Step 4: Confirm the old animation is fully gone**

Run:
```bash
grep -rn "ListeningMicAura\|tipText\|flowSubtitle" UcapHutang UcapHutangTests || echo "none"
```
Expected: `none`.

- [ ] **Step 5: Commit**

```bash
git add UcapHutang/Features/Catat/Views/CatatView.swift
git commit -m "feat: replace the Catat listening animation with a flow-colored sonar ping"
```

---

### Task 6: Spec amendment and final verification

**Files:**
- Modify: `docs/superpowers/specs/2026-09-12-voice-draft-remediation-design.md`

**Interfaces:**
- Consumes: everything from Tasks 1–5.
- Produces: no code.

- [ ] **Step 1: Amend the original spec's readiness-gate line**

In `docs/superpowers/specs/2026-09-12-voice-draft-remediation-design.md`, find this line in §7.4:

```
- Model readiness gate on the flow chooser stays.
```

Replace it with:

```
- Model readiness gate on the flow chooser stays, but silently: disabled tiles show no status text, banner, or caption. Amended 2026-09-14 — see `docs/superpowers/specs/2026-09-14-catat-ui-ux-design.md` §7.
```

- [ ] **Step 2: Final automated verification**

Run:
```bash
git status --short
```
Expected: only the file from Step 1 modified (plus any pre-existing untracked `.xcede/`/`xcede.yml`, which stay untouched).

Run:
```bash
grep -rn "ListeningMicAura\|MLXQwenClient.readiness().title\|MLXQwenClient.readiness().detail" UcapHutang UcapHutangTests || echo "none"
```
Expected: `none` (confirms no leftover reference to the removed animation or to the readiness status text that used to be shown).

Run the full test command.
Expected: `Executed 140 tests, with 0 failures`, `TEST SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-09-12-voice-draft-remediation-design.md
git commit -m "docs: amend readiness-gate wording after the Catat UI/UX redesign"
```

- [ ] **Step 4: Manual QA on the simulator (developer checkpoint)**

Hand this checklist to the developer and wait for their results. Do not push.

1. Catat tab → both tiles show their icon, title, and example ucapan; no readiness text/banner appears anywhere, even right after a fresh launch while the model is still loading (tiles are just visually dimmed and untappable).
2. Tap the Utang/Piutang tile: header, "Contoh Ucapan" label/icon, and (once you start speaking) the "Mendengarkan..." dot/text and the transcript card's border are all **blue**.
3. Tap Split Bill instead: the same elements are **orange**.
4. While recording and speaking normally, watch the mic button: a ring pops into view and expands outward while fading, once per louder moment — not continuously, not multiple rings at once. The mic icon keeps its gentle wobble throughout.
5. Speak continuously above a normal volume for 2+ seconds: pings are spaced out (at least ~0.7s apart), never overlapping or firing every frame.
6. Settings → Accessibility → Motion → Reduce Motion → on: the ring still appears briefly on a loud moment (fixed size, quick fade) instead of the growing ripple, and never disappears entirely.
7. Dynamic Type at the largest accessibility size: neither tile clips its example text; the mic control and ping ring scale down together, staying legible and non-overlapping.
8. Dark Mode: tiles, accent colors, and the ping remain legible and correctly tinted.
