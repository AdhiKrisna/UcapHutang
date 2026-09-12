import Foundation
import Observation

@Observable
final class NotificationPrimerViewModel {
    private(set) var isFinished = false

    private let scheduler: any ReminderScheduling
    private let settingsStore: any ReminderSettingsStore

    init(scheduler: any ReminderScheduling, settingsStore: any ReminderSettingsStore) {
        self.scheduler = scheduler
        self.settingsStore = settingsStore
    }

    /// The primer appears once, on launch, only while notification permission has never been decided.
    static func shouldShow(scheduler: any ReminderScheduling, settingsStore: any ReminderSettingsStore) async -> Bool {
        guard !settingsStore.hasSeenNotificationPrimer else { return false }
        return await scheduler.access() == .notDetermined
    }

    func allow() async {
        settingsStore.hasSeenNotificationPrimer = true
        _ = await scheduler.requestAccess()
        await scheduler.sync()
        isFinished = true
    }

    func later() async {
        settingsStore.hasSeenNotificationPrimer = true
        await scheduler.sync()
        isFinished = true
    }
}
