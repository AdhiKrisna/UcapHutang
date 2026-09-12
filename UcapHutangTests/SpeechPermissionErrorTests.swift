import XCTest
@testable import UcapHutang

final class SpeechPermissionErrorTests: XCTestCase {
    func testPermissionMessagesPointToPengaturan() {
        XCTAssertEqual(SpeechPermissionError.microphoneDenied.errorDescription, "Izin mikrofon ditolak. Buka Pengaturan untuk mengaktifkan.")
        XCTAssertEqual(SpeechPermissionError.speechDenied.errorDescription, "Izin Speech Recognition ditolak. Buka Pengaturan untuk mengaktifkan.")
        XCTAssertEqual(SpeechPermissionError.restricted.errorDescription, "Speech Recognition dibatasi pada perangkat ini.")
    }
}
