import XCTest
@testable import UcapHutang

@MainActor
final class AppRouterTests: XCTestCase {
    func testSavedBannerOpensTheReviewTabAndClears() {
        let router = AppRouter()
        router.selectedTab = .capture

        router.showSavedToReviewBanner()
        XCTAssertNotNil(router.savedBannerID)

        router.openReviewFromBanner()
        XCTAssertEqual(router.selectedTab, .review)
        XCTAssertNil(router.savedBannerID)

        router.showSavedToReviewBanner()
        router.dismissSavedBanner()
        XCTAssertNil(router.savedBannerID)
        XCTAssertEqual(router.selectedTab, .review)
    }

    func testCatatDeepLinkSelectsTheCaptureTab() {
        let router = AppRouter()
        router.selectedTab = .ledger

        router.open(.catatChooser)

        XCTAssertEqual(router.selectedTab, .capture)
    }

    func testOpenReviewSelectsTabAndPublishesDraftOnce() {
        let router = AppRouter()
        let draftID = UUID()
        router.selectedTab = .capture

        router.openReview(draftID: draftID)

        XCTAssertEqual(router.selectedTab, .review)
        XCTAssertEqual(router.consumePendingReviewDraft(), draftID)
        XCTAssertNil(router.consumePendingReviewDraft())
    }
}
