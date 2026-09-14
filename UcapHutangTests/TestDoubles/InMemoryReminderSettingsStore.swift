import Foundation
@testable import UcapHutang

@MainActor
final class InMemoryReminderSettingsStore: ReminderSettingsStore {
    var settings: ReminderSettings
    var hasSeenNotificationPrimer: Bool

    init(settings: ReminderSettings = ReminderSettings(), hasSeenNotificationPrimer: Bool = false) {
        self.settings = settings
        self.hasSeenNotificationPrimer = hasSeenNotificationPrimer
    }
}
