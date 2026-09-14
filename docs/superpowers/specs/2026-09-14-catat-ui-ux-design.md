# Catat UI/UX Design

**Status:** approved by product owner 2026-09-14, via `superpowers:brainstorming` with the browser visual companion (chooser-layout and mic-animation mockups).

## 1. Scope

All three parts of the Catat flow were in scope:

1. The flow chooser screen ("Pilih jenis pencatatan").
2. The recording screen (mic button, live transcript, listening animation).
3. The transition after recording finishes.

**Decision on (3): no changes.** The "Tersimpan ke Review" banner, the Review tab badge, and the success haptic already work well and are explicitly kept as-is.

This spec only covers (1) and (2).

## 2. Problem statement

- The flow chooser (`CatatFlowChooserView`) currently renders two plain rows (icon, title, chevron) with no description and no visible model-readiness status, even though the original spec (`2026-09-12-voice-draft-remediation-design.md` §7.4) called for a readiness gate on this screen. It reads as informative but bare.
- The recording screen's listening animation (`ListeningMicAura`: a blue/purple radial glow plus three independently pulsing rings, alongside a wobbling mic icon) was judged **simultaneously too busy** (multiple competing motions), **too subtle** (the audio-reactive part barely reads as "responding to your voice"), and **generic** (a blurred aura is a common, uninspired pattern).
- Color throughout the recording screen is a fixed blue (`AppColors.accent`) regardless of which flow (Utang/Piutang vs Split Bill) the user is in — described as "monoton".

## 3. Architecture: `CaptureFlow` metadata as a single source of truth

`CaptureFlow` (in `UcapHutang/Domain/Models/TransactionModels.swift`) gains four computed properties, replacing logic and copy currently duplicated between `CatatFlowChooserView` (`flowIcon`, `flowAccent`) and `CatatView` (`tipText`, `flowSubtitle`):

```swift
extension CaptureFlow {
    /// Drives every flow-colored element on the chooser and recording screens:
    /// tile background/border, the sonar ping, the listening status dot/border,
    /// and the "Contoh Ucapan" label.
    var accentColor: Color {
        switch self {
        case .personal: AppColors.accent   // existing token, unchanged
        case .splitBill: AppColors.split   // existing token, unchanged
        }
    }

    var icon: String {
        switch self {
        case .personal: "person.2"
        case .splitBill: "person.3.fill"
        }
    }

    /// The recording screen's subtitle, directly under the flow title. Not shown on the
    /// chooser tile — the tile uses `exampleUcapan` instead (see §4). Wording unchanged
    /// from the current `CatatView.flowSubtitle`.
    var subtitle: String {
        switch self {
        case .personal: "Catat utang atau piutang personal dengan satu orang"
        case .splitBill: "Catat patungan/bagi rata makan atau belanja bareng"
        }
    }

    /// Baked into the chooser tile and used as the recording screen's "Contoh Ucapan".
    var exampleUcapan: String {
        switch self {
        case .personal: "Dito pinjam 50 ribu buat beli bensin"
        case .splitBill: "Split bill makan 100 ribu sama Satria dan Arif bagi rata"
        }
    }
}
```

No new colors: `accentColor` reuses the existing `AppColors.accent`/`AppColors.split` tokens. Both `CatatFlowChooserView` and `CatatView` read from these four properties instead of holding their own copies.

## 4. Flow chooser screen

Redesigned as two large tiles (mockup option "C" — approved), replacing the current plain rows:

- Screen title stays "Pilih jenis pencatatan" (`.largeTitle.weight(.semibold)`) — unchanged.
- One tile per `CaptureFlow.allCases`, each:
  - A small rounded-square icon badge (32×32pt, corner radius 10, `flow.accentColor.opacity(0.16)` background, `flow.icon` glyph in `flow.accentColor`).
  - `flow.title` (existing property) as a bold headline.
  - `flow.exampleUcapan` as an italic quote — teaches the user how to phrase their recording directly from the tile, no separate instructions needed.
  - Background: a subtle diagonal gradient of `flow.accentColor` from `0.10` opacity (top-leading) to `0.02` (bottom-trailing).
  - Border: `flow.accentColor.opacity(0.18)`, continuous rounded rectangle.
  - Height driven by content (`minHeight`, not a fixed height) so larger Dynamic Type sizes never clip the example text.
  - No chevron — the whole tile is the tap target, matching a choice-card pattern (e.g. Shortcuts' "choose action").
- **Model readiness gate stays, but silently.** Tiles use `.disabled(readiness != .ready)` exactly as today. No visible text, banner, or caption explains *why* a tile is disabled — this explicitly supersedes the "gate... stays" wording in the original spec, which is amended below (§7).
- The "Tersimpan ke Review" banner (`.safeAreaInset(edge: .top)`, driven by `router.savedBannerID`) is unchanged.

## 5. Recording screen

### 5.1 Sonar ping (replaces the aura + three rings)

- `ListeningMicAura` is deleted. A new `SonarPingRing` view renders a single ring that expands once and fades out whenever the user's voice gets loud enough, then disappears — approved mockup option "C" ("ping sonar saat suara mengeras").
- Visual parameters (matched to the approved interactive demo):
  - Stroke ring, width 2.5pt, color `flow.accentColor`.
  - On fire: scale 1.0 → 2.1, opacity 0.55 → 0, over 0.9s, `.easeOut`.
  - At rest: invisible (no ring shown while quiet).
- Trigger rule, extracted into a plain, unit-testable type (no SwiftUI dependency):

```swift
/// Core/Utilities/SonarPingTrigger.swift
struct SonarPingTrigger {
    var threshold: Float = 0.78
    var cooldown: TimeInterval = 0.7

    /// `level` is `SpeechTranscribing.audioLevel` (0...1, already smoothed).
    func shouldFire(level: Float, now: Date, lastFire: Date?) -> Bool {
        guard level >= threshold else { return false }
        guard let lastFire else { return true }
        return now.timeIntervalSince(lastFire) >= cooldown
    }
}
```

- The view polls `speech.audioLevel` (already exposed by `SpeechTranscribing`, no protocol change needed), asks `SonarPingTrigger.shouldFire`, and on `true` replays the expand-and-fade animation once — implemented with SwiftUI's `PhaseAnimator(_:trigger:)` (iOS 17+, available on this project's iOS 26.5 floor), which is built for exactly this "replay a phase sequence once per trigger change" case instead of a manual `DispatchQueue`/`Task.sleep` delay.
- **Reduce Motion:** the ring still appears on a fire event (so a peak remains perceivable) but without the expand animation — it shows briefly at a fixed size/opacity instead of disappearing entirely, per this project's existing Reduce Motion convention.
- `SpeakingMicIcon`'s gentle wobble while listening is **kept, unchanged** — the ping is additive, not a replacement for it.

### 5.2 Flow-colored elements

`flow.accentColor` replaces the hardcoded `AppColors.accent` in:

- The "Mendengarkan..." status dot and its label text.
- The listening-transcript card's border (`AppColors.accent.opacity(0.3)` → `flow.accentColor.opacity(0.3)`).
- The "Contoh Ucapan" label and its `lightbulb.fill` icon (idle state).
- The sonar ping (§5.1).

**Stays neutral (not flow-colored):**
- The dashed circular stroke around the record button (button boundary chrome, not a state indicator).
- The "Contoh Ucapan" card's border in the idle state (`AppColors.border`) — only the *listening* card border becomes flow-colored, since color there also signals "recording in progress", not just flow identity.

If either of these should also become flow-colored, that's a one-line change in the implementation plan — flagged here as an explicit (reversible) interpretation, not a firm requirement.

## 6. Testing

- `DomainModelDefaultsTests`: one test per `CaptureFlow` case asserting `accentColor`, `icon`, `subtitle`, `exampleUcapan`.
- New `SonarPingTriggerTests`: below threshold never fires; at/above threshold with no prior fire fires; a second call inside the cooldown window does not fire; a call after the cooldown has elapsed fires again.
- No changes to `ReviewDetailViewModel`, any repository, `DraftValidator`, or the voice→LLM→draft pipeline (§7.1–7.3 of the original spec) — this is UI/animation only. The existing 134-test suite must keep passing unmodified.

## 7. Amendment to the original spec

`2026-09-12-voice-draft-remediation-design.md` §7.4 said: *"Model readiness gate on the flow chooser stays."* This is amended to: **the gate (disabling the tiles via `readiness != .ready`) stays, but with no visible status text, banner, or caption — disabled tiles look and behave exactly like any other disabled SwiftUI control, with no explanation shown.**

## 8. Out of scope

- The transition after recording (banner, badge, haptic) — confirmed unchanged.
- The voice→LLM→draft pipeline and its error handling.
- `RootTabView`'s wiring to `CatatFlowChooserView`/`CatatView` — call sites are unchanged.
