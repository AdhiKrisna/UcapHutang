import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    /// Attached by `UcapHutangApp` once the container exists.
    var router: AppRouter? {
        didSet { applyPendingDestination() }
    }

    private var pendingDestination: String?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // No banner while the app is open; the reminder still goes to Notification Center.
        [.list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let destination = response.notification.request.content.userInfo["destination"] as? String
        await MainActor.run {
            self.handleNotification(destination: destination)
        }
    }

    func handleNotification(destination: String?) {
        guard destination == "review" else { return }
        pendingDestination = destination
        applyPendingDestination()
    }

    private func applyPendingDestination() {
        guard let router, pendingDestination == "review" else { return }
        router.selectedTab = .review
        pendingDestination = nil
    }
}
