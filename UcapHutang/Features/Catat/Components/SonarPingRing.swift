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
        PhaseAnimator([Phase.idle, .start, .expanded, .idle], trigger: trigger) { phase in
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
