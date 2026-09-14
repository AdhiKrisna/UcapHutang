import XCTest
import UserNotifications
@testable import UcapHutang

@MainActor
final class ReviewReminderSchedulerTests: XCTestCase {
    private func repository(pendingDrafts count: Int) async throws -> InMemoryTransactionRepository {
        let repository = InMemoryTransactionRepository()
        for index in 0..<count {
            try await repository.saveDraft(TransactionDraft(
                flow: .personal,
                type: .unknown,
                title: "Catatan \(index)",
                totalAmount: 0,
                participants: [],
                rawTranscript: "catatan \(index)"
            ))
        }
        return repository
    }

    func testSchedulesOneSilentDailyReminderWithApprovedContent() async throws {
        let center = FakeNotificationCenterClient(status: .authorized)
        let store = InMemoryReminderSettingsStore(settings: ReminderSettings(isEnabled: true, hour: 20, minute: 0))
        let scheduler = ReviewReminderScheduler(center: center, settingsStore: store, repository: try await repository(pendingDrafts: 3))

        await scheduler.sync()
        await scheduler.sync()

        XCTAssertEqual(center.pendingRequests.count, 1, "Re-syncing must not duplicate the reminder")
        let request = try XCTUnwrap(center.pendingRequests.first)
        XCTAssertEqual(request.identifier, "review-reminder")
        XCTAssertEqual(request.content.title, "Ada catatan yang perlu ditinjau")
        XCTAssertEqual(request.content.body, "Kamu punya 3 catatan yang belum disimpan ke Riwayat.")
        XCTAssertNil(request.content.sound)
        XCTAssertEqual(request.content.userInfo["destination"] as? String, "review")
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        XCTAssertTrue(trigger.repeats)
        XCTAssertEqual(trigger.dateComponents.hour, 20)
        XCTAssertEqual(trigger.dateComponents.minute, 0)
    }

    func testNoReminderWhenNoDraftsArePending() async throws {
        let center = FakeNotificationCenterClient(status: .authorized)
        let scheduler = ReviewReminderScheduler(
            center: center,
            settingsStore: InMemoryReminderSettingsStore(),
            repository: try await repository(pendingDrafts: 0)
        )

        await scheduler.sync()

        XCTAssertTrue(center.pendingRequests.isEmpty)
        XCTAssertEqual(center.removedIdentifiers, [["review-reminder"]])
    }

    func testNoReminderWhenRemindersAreTurnedOff() async throws {
        let center = FakeNotificationCenterClient(status: .authorized)
        let store = InMemoryReminderSettingsStore(settings: ReminderSettings(isEnabled: false, hour: 20, minute: 0))
        let scheduler = ReviewReminderScheduler(center: center, settingsStore: store, repository: try await repository(pendingDrafts: 2))

        await scheduler.sync()

        XCTAssertTrue(center.pendingRequests.isEmpty)
    }

    func testNoReminderWithoutNotificationPermission() async throws {
        let center = FakeNotificationCenterClient(status: .denied)
        let scheduler = ReviewReminderScheduler(
            center: center,
            settingsStore: InMemoryReminderSettingsStore(),
            repository: try await repository(pendingDrafts: 2)
        )

        await scheduler.sync()

        XCTAssertTrue(center.pendingRequests.isEmpty)
    }

    func testRequestAccessAsksForAlertsOnlyAndTreatsProvisionalAsAuthorized() async throws {
        let center = FakeNotificationCenterClient(status: .notDetermined, statusAfterRequest: .provisional)
        let scheduler = ReviewReminderScheduler(
            center: center,
            settingsStore: InMemoryReminderSettingsStore(),
            repository: try await repository(pendingDrafts: 0)
        )

        let access = await scheduler.requestAccess()

        XCTAssertEqual(access, .authorized)
        XCTAssertEqual(center.requestedOptions, [[.alert]])
        XCTAssertEqual(ReviewReminderScheduler.map(.denied), .denied)
        XCTAssertEqual(ReviewReminderScheduler.map(.notDetermined), .notDetermined)
        XCTAssertEqual(ReviewReminderScheduler.map(.ephemeral), .authorized)
    }
}
