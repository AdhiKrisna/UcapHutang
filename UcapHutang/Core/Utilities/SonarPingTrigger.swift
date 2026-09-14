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
