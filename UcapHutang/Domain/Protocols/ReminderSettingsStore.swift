import Foundation

@MainActor
protocol ReminderSettingsStore: AnyObject {
    var settings: ReminderSettings { get set }
    var hasSeenNotificationPrimer: Bool { get set }
}
