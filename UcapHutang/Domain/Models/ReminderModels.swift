import Foundation

struct ReminderSettings: Equatable, Sendable {
    var isEnabled: Bool = true
    var hour: Int = 20
    var minute: Int = 0
}

enum NotificationAccess: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
}
