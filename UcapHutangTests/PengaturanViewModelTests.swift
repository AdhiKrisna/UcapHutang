import XCTest
@testable import UcapHutang

@MainActor
final class PengaturanViewModelTests: XCTestCase {
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    func testTurningRemindersOffPersistsAndSyncs() async {
        let scheduler = FakeReminderScheduler(access: .authorized)
        let store = InMemoryReminderSettingsStore()
        let viewModel = PengaturanViewModel(scheduler: scheduler, settingsStore: store, calendar: utcCalendar)
        XCTAssertTrue(viewModel.isReminderEnabled)

        await viewModel.setReminderEnabled(false)

        XCTAssertFalse(viewModel.isReminderEnabled)
        XCTAssertFalse(store.settings.isEnabled)
        XCTAssertEqual(scheduler.syncCallCount, 1)
    }

    func testChangingTheTimePersistsHourAndMinuteAndSyncs() async {
        let scheduler = FakeReminderScheduler(access: .authorized)
        let store = InMemoryReminderSettingsStore()
        let calendar = utcCalendar
        let viewModel = PengaturanViewModel(scheduler: scheduler, settingsStore: store, calendar: calendar)
        let sevenThirty = calendar.date(from: DateComponents(year: 2026, month: 9, day: 12, hour: 7, minute: 30))!

        await viewModel.setReminderTime(sevenThirty)

        XCTAssertEqual(store.settings.hour, 7)
        XCTAssertEqual(store.settings.minute, 30)
        XCTAssertEqual(calendar.component(.hour, from: viewModel.reminderTime), 7)
        XCTAssertEqual(calendar.component(.minute, from: viewModel.reminderTime), 30)
        XCTAssertEqual(scheduler.syncCallCount, 1)
    }

    func testRequestingAccessUpdatesStatusAndSyncs() async {
        let scheduler = FakeReminderScheduler(access: .notDetermined, accessAfterRequest: .authorized)
        let viewModel = PengaturanViewModel(scheduler: scheduler, settingsStore: InMemoryReminderSettingsStore(), calendar: utcCalendar)
        await viewModel.refreshAccess()
        XCTAssertEqual(viewModel.access, .notDetermined)

        await viewModel.requestAccess()

        XCTAssertEqual(viewModel.access, .authorized)
        XCTAssertEqual(scheduler.requestAccessCallCount, 1)
        XCTAssertEqual(scheduler.syncCallCount, 1)
    }
}
