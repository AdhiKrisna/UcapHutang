import Foundation
@testable import UcapHutang

@MainActor
final class SpyVoiceCapture: VoiceCapturing {
    struct Call: Equatable {
        let flow: CaptureFlow
        let transcript: String
    }

    var result: Result<UUID, Error> = .success(UUID())
    private(set) var calls: [Call] = []

    func process(flow: CaptureFlow, transcript: String) async throws -> UUID {
        calls.append(Call(flow: flow, transcript: transcript))
        return try result.get()
    }
}
