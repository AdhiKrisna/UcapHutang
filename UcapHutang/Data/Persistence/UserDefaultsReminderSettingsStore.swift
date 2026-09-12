import Foundation

final class UserDefaultsReminderSettingsStore: ReminderSettingsStore {
    enum Key {
        static let isEnabled = "reminder.isEnabled"
        static let hour = "reminder.hour"
        static let minute = "reminder.minute"
        static let primerSeen = "onboarding.notificationPrimerSeen"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.isEnabled: true,
            Key.hour: 20,
            Key.minute: 0,
            Key.primerSeen: false
        ])
    }

    var settings: ReminderSettings {
        get {
            ReminderSettings(
                isEnabled: defaults.bool(forKey: Key.isEnabled),
                hour: defaults.integer(forKey: Key.hour),
                minute: defaults.integer(forKey: Key.minute)
            )
        }
        set {
            defaults.set(newValue.isEnabled, forKey: Key.isEnabled)
            defaults.set(newValue.hour, forKey: Key.hour)
            defaults.set(newValue.minute, forKey: Key.minute)
        }
    }

    var hasSeenNotificationPrimer: Bool {
        get { defaults.bool(forKey: Key.primerSeen) }
        set { defaults.set(newValue, forKey: Key.primerSeen) }
    }
}
