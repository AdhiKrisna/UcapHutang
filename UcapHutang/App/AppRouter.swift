import Foundation
import Observation

enum AppTab: Hashable {
    case review
    case capture
    case ledger
}

@Observable
final class AppRouter {
    var selectedTab: AppTab = .review
    /// Non-nil while the "Tersimpan ke Review" banner is visible. A new ID restarts the banner timer.
    private(set) var savedBannerID: UUID?

    func showSavedToReviewBanner() {
        savedBannerID = UUID()
    }

    func dismissSavedBanner() {
        savedBannerID = nil
    }

    func openReviewFromBanner() {
        selectedTab = .review
        savedBannerID = nil
    }
}
