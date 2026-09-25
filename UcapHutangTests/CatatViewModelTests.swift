import XCTest
@testable import UcapHutang

@MainActor
final class CatatViewModelTests: XCTestCase {
    func testSuccessfulCaptureReportsTheSavedDraft() async {
        let speech = FakeSpeechTranscriber(finalTranscript: "Satria ngutang 20 ribu")
        let capture = SpyVoiceCapture()
        let savedID = UUID()
        capture.result = .success(savedID)
        let viewModel = CatatViewModel(flow: .personal, speech: speech, capture: capture)

        await viewModel.handleMicTap()
        XCTAssertTrue(viewModel.isListening)
        XCTAssertEqual(viewModel.recordButtonLabel, "Berhenti merekam")

        await viewModel.handleMicTap()

        XCTAssertEqual(viewModel.savedDraftID, savedID)
        XCTAssertEqual(capture.calls, [SpyVoiceCapture.Call(flow: .personal, transcript: "Satria ngutang 20 ribu")])
        XCTAssertFalse(viewModel.isProcessing)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testEmptyTranscriptShowsNoSpeechMessage() async {
        let speech = FakeSpeechTranscriber(finalTranscript: "   ", liveTranscript: "")
        let capture = SpyVoiceCapture()
        let viewModel = CatatViewModel(flow: .personal, speech: speech, capture: capture)

        await viewModel.handleMicTap()
        await viewModel.handleMicTap()

        XCTAssertEqual(viewModel.errorMessage, "Suara tidak terdeteksi. Silakan coba lagi.")
        XCTAssertTrue(capture.calls.isEmpty)
        XCTAssertNil(viewModel.savedDraftID)
    }

    func testFallsBackToLiveTranscriptWhenFinalIsEmpty() async {
        let speech = FakeSpeechTranscriber(finalTranscript: "", liveTranscript: "Dito pinjam 50 ribu")
        let capture = SpyVoiceCapture()
        let viewModel = CatatViewModel(flow: .personal, speech: speech, capture: capture)

        await viewModel.handleMicTap()
        await viewModel.handleMicTap()

        XCTAssertEqual(capture.calls.map(\.transcript), ["Dito pinjam 50 ribu"])
    }

    func testMicrophoneDeniedShowsInlinePermissionMessage() async {
        let speech = FakeSpeechTranscriber(startError: SpeechPermissionError.microphoneDenied)
        let viewModel = CatatViewModel(flow: .splitBill, speech: speech, capture: SpyVoiceCapture())

        await viewModel.handleMicTap()

        XCTAssertEqual(viewModel.permissionMessage, "Izin mikrofon ditolak. Buka Pengaturan untuk mengaktifkan.")
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isListening)
    }

    func testCaptureFailureShowsTheErrorAndSavesNothing() async {
        let speech = FakeSpeechTranscriber(finalTranscript: "Satria ngutang 20 ribu")
        let capture = SpyVoiceCapture()
        capture.result = .failure(DraftExtractionError.extractionFailed("model error"))
        let viewModel = CatatViewModel(flow: .personal, speech: speech, capture: capture)

        await viewModel.handleMicTap()
        await viewModel.handleMicTap()

        XCTAssertEqual(viewModel.errorMessage, "Ekstraksi gagal: model error")
        XCTAssertNil(viewModel.savedDraftID)
    }

    func testManualTranscriptCanBeSubmittedWithoutStartingMicrophone() async {
        let capture = SpyVoiceCapture()
        let savedID = UUID()
        capture.result = .success(savedID)
        let viewModel = CatatViewModel(flow: .splitBill, speech: FakeSpeechTranscriber(), capture: capture)
        viewModel.manualTranscript = "  Split bill makan sama Satria dan Arif  "

        await viewModel.submitManualTranscript()

        XCTAssertEqual(viewModel.savedDraftID, savedID)
        XCTAssertEqual(capture.calls, [SpyVoiceCapture.Call(flow: .splitBill, transcript: "Split bill makan sama Satria dan Arif")])
    }

    func testManualTranscriptCannotBeSubmittedWhileListening() async {
        let capture = SpyVoiceCapture()
        let viewModel = CatatViewModel(flow: .personal, speech: FakeSpeechTranscriber(), capture: capture)
        viewModel.manualTranscript = "Aku pinjam dari Dito"

        await viewModel.handleMicTap()
        await viewModel.submitManualTranscript()

        XCTAssertTrue(capture.calls.isEmpty)
    }
}
