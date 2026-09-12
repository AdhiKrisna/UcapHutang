import Foundation
import Observation

@Observable
final class PengaturanViewModel {
    private(set) var isReminderEnabled: Bool
    private(set) var reminderTime: Date
    private(set) var access: NotificationAccess = .notDetermined

    private let scheduler: any ReminderScheduling
    private let settingsStore: any ReminderSettingsStore
    private let calendar: Calendar

    init(
        scheduler: any ReminderScheduling,
        settingsStore: any ReminderSettingsStore,
        calendar: Calendar = .current
    ) {
        self.scheduler = scheduler
        self.settingsStore = settingsStore
        self.calendar = calendar
        let settings = settingsStore.settings
        self.isReminderEnabled = settings.isEnabled
        self.reminderTime = Self.date(hour: settings.hour, minute: settings.minute, calendar: calendar)
    }

    func refreshAccess() async {
        access = await scheduler.access()
    }

    func setReminderEnabled(_ isEnabled: Bool) async {
        isReminderEnabled = isEnabled
        var settings = settingsStore.settings
        settings.isEnabled = isEnabled
        settingsStore.settings = settings
        await scheduler.sync()
    }

    func setReminderTime(_ date: Date) async {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        var settings = settingsStore.settings
        settings.hour = components.hour ?? settings.hour
        settings.minute = components.minute ?? settings.minute
        settingsStore.settings = settings
        reminderTime = Self.date(hour: settings.hour, minute: settings.minute, calendar: calendar)
        await scheduler.sync()
    }

    func requestAccess() async {
        access = await scheduler.requestAccess()
        await scheduler.sync()
    }

    private static func date(hour: Int, minute: Int, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }
}
