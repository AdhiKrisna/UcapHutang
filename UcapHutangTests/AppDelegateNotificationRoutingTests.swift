import XCTest
@testable import UcapHutang

@MainActor
final class AppDelegateNotificationRoutingTests: XCTestCase {
    func testReviewDestinationOpensReviewTabEvenBeforeRouterIsAttached() {
        let delegate = AppDelegate()

        delegate.handleNotification(destination: "review")
        let router = AppRouter()
        router.selectedTab = .ledger
        delegate.router = router
        XCTAssertEqual(router.selectedTab, .review)

        router.selectedTab = .capture
        delegate.handleNotification(destination: "review")
        XCTAssertEqual(router.selectedTab, .review)

        delegate.handleNotification(destination: "other")
        XCTAssertEqual(router.selectedTab, .review, "Unknown destinations must not change the tab")
    }
}
