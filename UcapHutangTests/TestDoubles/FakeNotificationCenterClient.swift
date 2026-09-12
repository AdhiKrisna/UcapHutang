import Foundation
import UserNotifications
@testable import UcapHutang

@MainActor
final class FakeNotificationCenterClient: NotificationCenterClient {
    var status: UNAuthorizationStatus
    var statusAfterRequest: UNAuthorizationStatus
    private(set) var requestedOptions: [UNAuthorizationOptions] = []
    private(set) var pendingRequests: [UNNotificationRequest] = []
    private(set) var removedIdentifiers: [[String]] = []

    init(status: UNAuthorizationStatus = .authorized, statusAfterRequest: UNAuthorizationStatus = .authorized) {
        self.status = status
        self.statusAfterRequest = statusAfterRequest
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        status
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestedOptions.append(options)
        status = statusAfterRequest
        return status == .authorized
    }

    func add(_ request: UNNotificationRequest) async throws {
        pendingRequests.removeAll { $0.identifier == request.identifier }
        pendingRequests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async {
        removedIdentifiers.append(identifiers)
        pendingRequests.removeAll { identifiers.contains($0.identifier) }
    }
}
