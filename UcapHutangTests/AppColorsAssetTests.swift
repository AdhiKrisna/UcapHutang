import XCTest
import UIKit
@testable import UcapHutang

final class AppColorsAssetTests: XCTestCase {
    func testReminderButtonBackgroundHasApprovedLightAndDarkValues() throws {
        let color = try XCTUnwrap(UIColor(named: "ReminderButtonBackground", in: Bundle.main, compatibleWith: nil))

        assertRGB(color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)), red: 0xFF, green: 0xF5, blue: 0xE0)
        assertRGB(color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)), red: 0x3A, green: 0x32, blue: 0x22)
    }

    private func assertRGB(_ color: UIColor, red: Int, green: Int, blue: Int, file: StaticString = #filePath, line: UInt = #line) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        XCTAssertTrue(color.getRed(&r, green: &g, blue: &b, alpha: &a), file: file, line: line)
        XCTAssertEqual(Int((r * 255).rounded()), red, file: file, line: line)
        XCTAssertEqual(Int((g * 255).rounded()), green, file: file, line: line)
        XCTAssertEqual(Int((b * 255).rounded()), blue, file: file, line: line)
        XCTAssertEqual(a, 1, accuracy: 0.001, file: file, line: line)
    }
}
