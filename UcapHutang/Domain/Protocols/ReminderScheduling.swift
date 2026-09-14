import Foundation

protocol ReminderScheduling: Sendable {
    func access() async -> NotificationAccess
    /// Shows the system prompt only when permission is not determined.
    func requestAccess() async -> NotificationAccess
    /// Re-schedules or removes the daily Review reminder from settings, permission, and the pending draft count.
    func sync() async
}
