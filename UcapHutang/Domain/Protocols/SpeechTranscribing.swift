import Foundation

/// Stage 1 contract: microphone audio → Indonesian transcript.
@MainActor
protocol SpeechTranscribing: AnyObject {
    var state: SpeechRecognizerState { get }
    var liveTranscript: String { get }
    /// True when the device can recognize `id-ID` speech without sending audio to Apple's servers.
    var usesOnDeviceRecognition: Bool { get }
    /// Requests microphone + speech permission when needed, then starts listening.
    /// Throws `SpeechPermissionError` or `SpeechRecognitionError`.
    func start() async throws
    /// Stops listening and waits (bounded) for the final transcript.
    func finish() async -> String
    func cancel()
}
