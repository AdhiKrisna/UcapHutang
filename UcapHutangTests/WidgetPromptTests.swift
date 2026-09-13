import XCTest
@testable import UcapHutang

@MainActor
final class WidgetPromptTests: XCTestCase {
    func testWidgetPromptWaitsForThePrimerAndIsAskedOnce() {
        XCTAssertTrue(WidgetPrompt.shouldPresent(hasAsked: false, isShowingNotificationPrimer: false))
        XCTAssertFalse(WidgetPrompt.shouldPresent(hasAsked: false, isShowingNotificationPrimer: true))
        XCTAssertFalse(WidgetPrompt.shouldPresent(hasAsked: true, isShowingNotificationPrimer: false))
        // Same key as PR #3 so testers who already answered are not asked again.
        XCTAssertEqual(WidgetPrompt.hasAskedKey, "hasAskedAboutCatatWidget")
    }
}
