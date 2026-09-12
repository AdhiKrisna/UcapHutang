import Foundation
@testable import UcapHutang

@MainActor
final class FakeSpeechTranscriber: SpeechTranscribing {
    var state: SpeechRecognizerState = .idle
    var liveTranscript: String
    var usesOnDeviceRecognition = true
    var startError: Error?
    var finalTranscript: String
    private(set) var cancelCallCount = 0

    init(finalTranscript: String = "", liveTranscript: String = "", startError: Error? = nil) {
        self.finalTranscript = finalTranscript
        self.liveTranscript = liveTranscript
        self.startError = startError
    }

    func start() async throws {
        if let startError { throw startError }
        state = .listening
    }

    func finish() async -> String {
        state = .idle
        return finalTranscript
    }

    func cancel() {
        cancelCallCount += 1
        state = .idle
    }
}
