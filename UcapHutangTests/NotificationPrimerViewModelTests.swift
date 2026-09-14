import XCTest
@testable import UcapHutang

@MainActor
final class NotificationPrimerViewModelTests: XCTestCase {
    func testShowsOnlyWhenNotSeenAndPermissionNotDetermined() async {
        let firstLaunch = await NotificationPrimerViewModel.shouldShow(
            scheduler: FakeReminderScheduler(access: .notDetermined),
            settingsStore: InMemoryReminderSettingsStore(hasSeenNotificationPrimer: false)
        )
        XCTAssertTrue(firstLaunch)

        let alreadySeen = await NotificationPrimerViewModel.shouldShow(
            scheduler: FakeReminderScheduler(access: .notDetermined),
            settingsStore: InMemoryReminderSettingsStore(hasSeenNotificationPrimer: true)
        )
        XCTAssertFalse(alreadySeen)

        let alreadyDecided = await NotificationPrimerViewModel.shouldShow(
            scheduler: FakeReminderScheduler(access: .denied),
            settingsStore: InMemoryReminderSettingsStore(hasSeenNotificationPrimer: false)
        )
        XCTAssertFalse(alreadyDecided)
    }

    func testAllowRequestsPermissionMarksSeenAndSyncs() async {
        let scheduler = FakeReminderScheduler(access: .notDetermined, accessAfterRequest: .authorized)
        let store = InMemoryReminderSettingsStore()
        let viewModel = NotificationPrimerViewModel(scheduler: scheduler, settingsStore: store)

        await viewModel.allow()

        XCTAssertEqual(scheduler.requestAccessCallCount, 1)
        XCTAssertEqual(scheduler.syncCallCount, 1)
        XCTAssertTrue(store.hasSeenNotificationPrimer)
        XCTAssertTrue(viewModel.isFinished)
    }

    func testLaterMarksSeenAndSyncsWithoutAskingPermission() async {
        let scheduler = FakeReminderScheduler(access: .notDetermined)
        let store = InMemoryReminderSettingsStore()
        let viewModel = NotificationPrimerViewModel(scheduler: scheduler, settingsStore: store)

        await viewModel.later()

        XCTAssertEqual(scheduler.requestAccessCallCount, 0)
        XCTAssertEqual(scheduler.syncCallCount, 1)
        XCTAssertTrue(store.hasSeenNotificationPrimer)
        XCTAssertTrue(viewModel.isFinished)
    }
}
