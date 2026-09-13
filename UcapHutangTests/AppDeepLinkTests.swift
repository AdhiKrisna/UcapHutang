import XCTest
@testable import UcapHutang

@MainActor
final class AppDeepLinkTests: XCTestCase {
    func testWidgetDeepLinkRoutesOnlyToCatatChooser() {
        XCTAssertEqual(AppDeepLink(url: URL(string: "ucaphutang://catat")!), .catatChooser)
        XCTAssertNil(AppDeepLink(url: URL(string: "ucaphutang://unknown")!))
        XCTAssertNil(AppDeepLink(url: URL(string: "https://example.com/catat")!))
    }
}
