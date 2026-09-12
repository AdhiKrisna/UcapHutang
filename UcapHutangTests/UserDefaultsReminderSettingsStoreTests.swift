import XCTest
@testable import UcapHutang

@MainActor
final class UserDefaultsReminderSettingsStoreTests: XCTestCase {
    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "UcapHutangTests.reminder.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, suiteName)
    }

    func testDefaultsAreEnabledAt2000AndPrimerNotSeen() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsReminderSettingsStore(defaults: defaults)

        XCTAssertEqual(store.settings, ReminderSettings(isEnabled: true, hour: 20, minute: 0))
        XCTAssertFalse(store.hasSeenNotificationPrimer)
    }

    func testChangesArePersistedUnderTheApprovedKeys() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsReminderSettingsStore(defaults: defaults)
        store.settings = ReminderSettings(isEnabled: false, hour: 7, minute: 30)
        store.hasSeenNotificationPrimer = true

        let reopened = UserDefaultsReminderSettingsStore(defaults: defaults)
        XCTAssertEqual(reopened.settings, ReminderSettings(isEnabled: false, hour: 7, minute: 30))
        XCTAssertTrue(reopened.hasSeenNotificationPrimer)
        XCTAssertEqual(defaults.object(forKey: "reminder.isEnabled") as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: "reminder.hour") as? Int, 7)
        XCTAssertEqual(defaults.object(forKey: "reminder.minute") as? Int, 30)
        XCTAssertEqual(defaults.object(forKey: "onboarding.notificationPrimerSeen") as? Bool, true)
    }
}
