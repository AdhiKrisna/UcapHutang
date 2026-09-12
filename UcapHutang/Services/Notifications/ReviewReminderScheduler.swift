import Foundation
import UserNotifications

final class ReviewReminderScheduler: ReminderScheduling {
    static let requestIdentifier = "review-reminder"

    private let center: any NotificationCenterClient
    private let settingsStore: any ReminderSettingsStore
    private let repository: any TransactionRepository

    init(
        center: any NotificationCenterClient,
        settingsStore: any ReminderSettingsStore,
        repository: any TransactionRepository
    ) {
        self.center = center
        self.settingsStore = settingsStore
        self.repository = repository
    }

    func access() async -> NotificationAccess {
        Self.map(await center.authorizationStatus())
    }

    func requestAccess() async -> NotificationAccess {
        let current = await access()
        guard current == .notDetermined else { return current }
        _ = try? await center.requestAuthorization(options: [.alert])
        return await access()
    }

    func sync() async {
        await center.removePendingNotificationRequests(withIdentifiers: [Self.requestIdentifier])

        let settings = settingsStore.settings
        guard settings.isEnabled, await access() == .authorized else { return }

        let pendingCount = (try? await repository.pendingDraftCount()) ?? 0
        guard pendingCount > 0 else { return }

        try? await center.add(Self.makeRequest(settings: settings, pendingCount: pendingCount))
    }

    static func makeRequest(settings: ReminderSettings, pendingCount: Int) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Ada catatan yang perlu ditinjau"
        content.body = "Kamu punya \(pendingCount) catatan yang belum disimpan ke Riwayat."
        content.userInfo = ["destination": "review"]
        // Silent by decision: `content.sound` stays nil.

        var components = DateComponents()
        components.hour = settings.hour
        components.minute = settings.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        return UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: trigger)
    }

    static func map(_ status: UNAuthorizationStatus) -> NotificationAccess {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        @unknown default:
            return .denied
        }
    }
}
