import Foundation
@testable import UcapHutang

@MainActor
final class FakeReminderScheduler: ReminderScheduling {
    var currentAccess: NotificationAccess
    var accessAfterRequest: NotificationAccess
    private(set) var requestAccessCallCount = 0
    private(set) var syncCallCount = 0

    init(access: NotificationAccess = .notDetermined, accessAfterRequest: NotificationAccess = .authorized) {
        self.currentAccess = access
        self.accessAfterRequest = accessAfterRequest
    }

    func access() async -> NotificationAccess {
        currentAccess
    }

    func requestAccess() async -> NotificationAccess {
        requestAccessCallCount += 1
        if currentAccess == .notDetermined {
            currentAccess = accessAfterRequest
        }
        return currentAccess
    }

    func sync() async {
        syncCallCount += 1
    }
}
