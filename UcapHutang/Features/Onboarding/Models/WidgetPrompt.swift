import Foundation

/// Decides when to ask "Catat lebih cepat dengan Widget?".
enum WidgetPrompt {
    /// `@AppStorage` key. Kept identical to PR #3 so people who already answered are not asked again.
    static let hasAskedKey = "hasAskedAboutCatatWidget"

    /// The widget question is asked once, and never while the notification primer is on screen.
    static func shouldPresent(hasAsked: Bool, isShowingNotificationPrimer: Bool) -> Bool {
        !hasAsked && !isShowingNotificationPrimer
    }
}
