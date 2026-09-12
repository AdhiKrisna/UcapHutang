import Foundation

/// Turns a finished transcript into a saved `needsReview` draft and returns its ID.
protocol VoiceCapturing: Sendable {
    func process(flow: CaptureFlow, transcript: String) async throws -> UUID
}
