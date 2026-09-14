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
