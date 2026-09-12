# P6 — Daily Review Reminder, Notification Primer, and Pengaturan Implementation Plan

> **For agentic workers (Gemini 3.7 Flash):** Execute the tasks in order, one step at a time. Steps use checkbox (`- [ ]`) syntax — tick each one as you finish it. When a step gives a complete file, replace the **entire** file with it. Never skip a "run the test and confirm it fails" step. If an actual result differs from the "Expected" text, stop and report instead of improvising.

**Goal:** Remind the user once a day, at a time they choose (default 20:00), while drafts are waiting in the Review tab; explain and request notification permission on first launch; and let the user change the reminder in a new Pengaturan screen opened from the Review tab.

**Architecture:** Settings live in `UserDefaults` behind `ReminderSettingsStore`. `ReviewReminderScheduler` (behind `ReminderScheduling`) talks to `UNUserNotificationCenter` through `NotificationCenterClient`, and keeps exactly one repeating local notification scheduled only when reminders are on, permission is granted, and at least one draft is pending. `RootTabView` re-syncs on launch, on every repository change, and when the app becomes active. `AppDelegate` routes a tapped notification to the Review tab via `AppRouter`.

**Tech Stack:** SwiftUI (iOS 26.5), Observation, UserNotifications, UIKit app delegate adaptor, XCTest.

**Spec:** `docs/superpowers/specs/2026-09-12-voice-draft-remediation-design.md` (§3, §10, §14 P6).

## Global Constraints

- Work on branch `fix/all`. **P0–P5 must be finished** and the developer must have confirmed the P5 checklist. Suite at start: 101 tests passing.
- **Never stage `.xcede/` or `xcede.yml`.** Always `git add` explicit paths; never `git add -A`, `git add .`, or `git commit -a`.
- Do not edit `UcapHutang.xcodeproj/project.pbxproj`. Local notifications need no Info.plist key.
- Build settings in effect (do not change): `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_VERSION = 5.0`.
- ViewModels import only `Foundation` and `Observation`. Views open URLs with `@Environment(\.openURL)`.
- Reminders are **silent**: request `[.alert]` only and never set `content.sound`.
- Exactly one pending request, identifier `review-reminder`, repeating daily at the chosen hour/minute.
- Foreground presentation: `[.list]` only (no banner while the app is open).
- UserDefaults keys and defaults: `reminder.isEnabled` = `true`, `reminder.hour` = `20`, `reminder.minute` = `0`, `onboarding.notificationPrimerSeen` = `false`.
- Exact user-facing copy (Indonesian) for this phase:

  | Where | Text |
  |-------|------|
  | Notification title | `Ada catatan yang perlu ditinjau` |
  | Notification body | `Kamu punya <jumlah> catatan yang belum disimpan ke Riwayat.` |
  | Primer title | `Pengingat Review` |
  | Primer body | `Kami akan mengingatkanmu setiap hari pukul 20.00 untuk meninjau catatan hasil rekaman. Jam pengingat bisa kamu ubah kapan saja di Pengaturan.` |
  | Primer buttons | `Izinkan Notifikasi` / `Nanti Saja` |
  | Gear button accessibility label | `Pengaturan` |
  | Settings title / done button | `Pengaturan` / `Selesai` |
  | Settings section header | `Pengingat` |
  | Toggle | `Pengingat Review` |
  | Time picker label | `Jam` |
  | Section footer | `Kamu akan diingatkan setiap hari pada jam ini selama masih ada catatan yang perlu ditinjau.` |
  | Permission not asked | button `Izinkan Notifikasi` |
  | Permission denied | text `Notifikasi dimatikan untuk UcapHutang.` + button `Buka Pengaturan` |

- Full test command:

  ```bash
  xcodebuild test -project UcapHutang.xcodeproj -scheme UcapHutang -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | grep -E "Test Case '.*' (passed|failed)|error:|Executed [0-9]+ tests|TEST SUCCEEDED|TEST FAILED"
  ```

- Single test class command (replace `<Class>`):

  ```bash
  xcodebuild test -project UcapHutang.xcodeproj -scheme UcapHutang -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:UcapHutangTests/<Class> 2>&1 | grep -E "Test Case '.*' (passed|failed)|error:|Executed [0-9]+ tests|TEST SUCCEEDED|TEST FAILED"
  ```

Expected test totals: start 101 → Task 1: 103 → Task 2: 108 → Task 3: 109 → Task 4: 112 → Task 5: 115 → Task 6: 115.

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `UcapHutang/Domain/Models/ReminderModels.swift` | Create | `ReminderSettings`, `NotificationAccess`. |
| `UcapHutang/Domain/Protocols/ReminderSettingsStore.swift` | Create | Settings persistence contract. |
| `UcapHutang/Domain/Protocols/ReminderScheduling.swift` | Create | Scheduling contract. |
| `UcapHutang/Data/Persistence/UserDefaultsReminderSettingsStore.swift` | Create | UserDefaults implementation. |
| `UcapHutang/Services/Notifications/NotificationCenterClient.swift` | Create | Testable wrapper over `UNUserNotificationCenter`. |
| `UcapHutang/Services/Notifications/ReviewReminderScheduler.swift` | Create | Keeps the single daily reminder in sync. |
| `UcapHutang/App/AppDelegate.swift` | Create | Notification delegate + routing. |
| `UcapHutang/UcapHutangApp.swift` | Replace | Delegate adaptor; attaches router. |
| `UcapHutang/Features/Onboarding/ViewModels/NotificationPrimerViewModel.swift` | Create | Primer logic. |
| `UcapHutang/Features/Onboarding/Views/NotificationPrimerView.swift` | Create | Primer screen. |
| `UcapHutang/Features/Pengaturan/ViewModels/PengaturanViewModel.swift` | Create | Settings logic. |
| `UcapHutang/Features/Pengaturan/Views/PengaturanView.swift` | Create | Settings screen. |
| `UcapHutang/App/AppContainer.swift` | Replace | Adds reminder dependencies. |
| `UcapHutang/App/RootTabView.swift` | Replace | Sync triggers, primer cover, settings sheet. |
| `UcapHutang/Features/Review/Views/ReviewListView.swift` | Replace | Gear toolbar button. |
| `UcapHutangTests/TestDoubles/InMemoryReminderSettingsStore.swift` | Create | Test double. |
| `UcapHutangTests/TestDoubles/FakeNotificationCenterClient.swift` | Create | Test double. |
| `UcapHutangTests/TestDoubles/FakeReminderScheduler.swift` | Create | Test double. |
| `UcapHutangTests/UserDefaultsReminderSettingsStoreTests.swift` | Create | Store tests. |
| `UcapHutangTests/ReviewReminderSchedulerTests.swift` | Create | Scheduler tests. |
| `UcapHutangTests/AppDelegateNotificationRoutingTests.swift` | Create | Routing test. |
| `UcapHutangTests/NotificationPrimerViewModelTests.swift` | Create | Primer tests. |
| `UcapHutangTests/PengaturanViewModelTests.swift` | Create | Settings tests. |

---

### Task 1: Reminder settings model and UserDefaults store

**Files:**
- Create: `UcapHutang/Domain/Models/ReminderModels.swift`
- Create: `UcapHutang/Domain/Protocols/ReminderSettingsStore.swift`
- Create: `UcapHutang/Data/Persistence/UserDefaultsReminderSettingsStore.swift`
- Create: `UcapHutangTests/TestDoubles/InMemoryReminderSettingsStore.swift`
- Create: `UcapHutangTests/UserDefaultsReminderSettingsStoreTests.swift`

**Interfaces:**
- Produces:
  - `struct ReminderSettings: Equatable, Sendable { var isEnabled: Bool = true; var hour: Int = 20; var minute: Int = 0 }`
  - `enum NotificationAccess: Equatable, Sendable { case notDetermined, authorized, denied }`
  - `@MainActor protocol ReminderSettingsStore: AnyObject { var settings: ReminderSettings { get set }; var hasSeenNotificationPrimer: Bool { get set } }`
  - `final class UserDefaultsReminderSettingsStore: ReminderSettingsStore` with `init(defaults: UserDefaults = .standard)`.
  - Test double `InMemoryReminderSettingsStore(settings:hasSeenNotificationPrimer:)`.

- [ ] **Step 1: Write the failing tests**

Create `UcapHutangTests/UserDefaultsReminderSettingsStoreTests.swift`:

```swift
import XCTest
@testable import UcapHutang

@MainActor
final class UserDefaultsReminderSettingsStoreTests: XCTestCase {
    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "UcapHutangTests.reminder.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, suiteName)
    }

    func testDefaultsAreEnabledAt2000AndPrimerNotSeen() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsReminderSettingsStore(defaults: defaults)

        XCTAssertEqual(store.settings, ReminderSettings(isEnabled: true, hour: 20, minute: 0))
        XCTAssertFalse(store.hasSeenNotificationPrimer)
    }

    func testChangesArePersistedUnderTheApprovedKeys() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsReminderSettingsStore(defaults: defaults)
        store.settings = ReminderSettings(isEnabled: false, hour: 7, minute: 30)
        store.hasSeenNotificationPrimer = true

        let reopened = UserDefaultsReminderSettingsStore(defaults: defaults)
        XCTAssertEqual(reopened.settings, ReminderSettings(isEnabled: false, hour: 7, minute: 30))
        XCTAssertTrue(reopened.hasSeenNotificationPrimer)
        XCTAssertEqual(defaults.object(forKey: "reminder.isEnabled") as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: "reminder.hour") as? Int, 7)
        XCTAssertEqual(defaults.object(forKey: "reminder.minute") as? Int, 30)
        XCTAssertEqual(defaults.object(forKey: "onboarding.notificationPrimerSeen") as? Bool, true)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run the single test class command with `<Class>` = `UserDefaultsReminderSettingsStoreTests`.

Expected: `error: cannot find 'UserDefaultsReminderSettingsStore' in scope`, `** TEST FAILED **`.

- [ ] **Step 3: Implement**

Create `UcapHutang/Domain/Models/ReminderModels.swift`:

```swift
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
```

Create `UcapHutang/Domain/Protocols/ReminderSettingsStore.swift`:

```swift
import Foundation

@MainActor
protocol ReminderSettingsStore: AnyObject {
    var settings: ReminderSettings { get set }
    var hasSeenNotificationPrimer: Bool { get set }
}
```

Create `UcapHutang/Data/Persistence/UserDefaultsReminderSettingsStore.swift`:

```swift
import Foundation

final class UserDefaultsReminderSettingsStore: ReminderSettingsStore {
    enum Key {
        static let isEnabled = "reminder.isEnabled"
        static let hour = "reminder.hour"
        static let minute = "reminder.minute"
        static let primerSeen = "onboarding.notificationPrimerSeen"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.isEnabled: true,
            Key.hour: 20,
            Key.minute: 0,
            Key.primerSeen: false
        ])
    }

    var settings: ReminderSettings {
        get {
            ReminderSettings(
                isEnabled: defaults.bool(forKey: Key.isEnabled),
                hour: defaults.integer(forKey: Key.hour),
                minute: defaults.integer(forKey: Key.minute)
            )
        }
        set {
            defaults.set(newValue.isEnabled, forKey: Key.isEnabled)
            defaults.set(newValue.hour, forKey: Key.hour)
            defaults.set(newValue.minute, forKey: Key.minute)
        }
    }

    var hasSeenNotificationPrimer: Bool {
        get { defaults.bool(forKey: Key.primerSeen) }
        set { defaults.set(newValue, forKey: Key.primerSeen) }
    }
}
```

Create `UcapHutangTests/TestDoubles/InMemoryReminderSettingsStore.swift`:

```swift
import Foundation
@testable import UcapHutang

@MainActor
final class InMemoryReminderSettingsStore: ReminderSettingsStore {
    var settings: ReminderSettings
    var hasSeenNotificationPrimer: Bool

    init(settings: ReminderSettings = ReminderSettings(), hasSeenNotificationPrimer: Bool = false) {
        self.settings = settings
        self.hasSeenNotificationPrimer = hasSeenNotificationPrimer
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run the single test class command with `<Class>` = `UserDefaultsReminderSettingsStoreTests`. Expected: `Executed 2 tests, with 0 failures`.

Run the full test command. Expected: `Executed 103 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add UcapHutang/Domain/Models/ReminderModels.swift UcapHutang/Domain/Protocols/ReminderSettingsStore.swift UcapHutang/Data/Persistence/UserDefaultsReminderSettingsStore.swift UcapHutangTests/TestDoubles/InMemoryReminderSettingsStore.swift UcapHutangTests/UserDefaultsReminderSettingsStoreTests.swift
git commit -m "feat: persist review reminder settings in UserDefaults"
```

---

### Task 2: Notification center client and review reminder scheduler

**Files:**
- Create: `UcapHutang/Domain/Protocols/ReminderScheduling.swift`
- Create: `UcapHutang/Services/Notifications/NotificationCenterClient.swift`
- Create: `UcapHutang/Services/Notifications/ReviewReminderScheduler.swift`
- Create: `UcapHutangTests/TestDoubles/FakeNotificationCenterClient.swift`
- Create: `UcapHutangTests/ReviewReminderSchedulerTests.swift`

**Interfaces:**
- Consumes: `ReminderSettings`, `NotificationAccess`, `ReminderSettingsStore` (Task 1); `TransactionRepository.pendingDraftCount()` (P2); `InMemoryReminderSettingsStore` (Task 1).
- Produces:
  - `protocol ReminderScheduling: Sendable { func access() async -> NotificationAccess; func requestAccess() async -> NotificationAccess; func sync() async }`
  - `protocol NotificationCenterClient: Sendable { func authorizationStatus() async -> UNAuthorizationStatus; func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool; func add(_ request: UNNotificationRequest) async throws; func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async }` and `struct SystemNotificationCenterClient: NotificationCenterClient`.
  - `final class ReviewReminderScheduler: ReminderScheduling` — `static let requestIdentifier = "review-reminder"`, `init(center: any NotificationCenterClient, settingsStore: any ReminderSettingsStore, repository: any TransactionRepository)`, `static func map(_ status: UNAuthorizationStatus) -> NotificationAccess`.

- [ ] **Step 1: Write the failing tests**

Create `UcapHutangTests/TestDoubles/FakeNotificationCenterClient.swift`:

```swift
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
```

Create `UcapHutangTests/ReviewReminderSchedulerTests.swift`:

```swift
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
```

- [ ] **Step 2: Run to verify it fails**

Run the single test class command with `<Class>` = `ReviewReminderSchedulerTests`.

Expected: `error: cannot find type 'NotificationCenterClient' in scope` (and `ReviewReminderScheduler`), `** TEST FAILED **`.

- [ ] **Step 3: Implement**

Create `UcapHutang/Domain/Protocols/ReminderScheduling.swift`:

```swift
import Foundation

protocol ReminderScheduling: Sendable {
    func access() async -> NotificationAccess
    /// Shows the system prompt only when permission is not determined.
    func requestAccess() async -> NotificationAccess
    /// Re-schedules or removes the daily Review reminder from settings, permission, and the pending draft count.
    func sync() async
}
```

Create `UcapHutang/Services/Notifications/NotificationCenterClient.swift`:

```swift
import Foundation
import UserNotifications

protocol NotificationCenterClient: Sendable {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async
}

struct SystemNotificationCenterClient: NotificationCenterClient {
    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: options)
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await UNUserNotificationCenter.current().add(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
```

Create `UcapHutang/Services/Notifications/ReviewReminderScheduler.swift`:

```swift
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
```

- [ ] **Step 4: Run to verify it passes**

Run the single test class command with `<Class>` = `ReviewReminderSchedulerTests`. Expected: `Executed 5 tests, with 0 failures`.

Run the full test command. Expected: `Executed 108 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add UcapHutang/Domain/Protocols/ReminderScheduling.swift UcapHutang/Services/Notifications/NotificationCenterClient.swift UcapHutang/Services/Notifications/ReviewReminderScheduler.swift UcapHutangTests/TestDoubles/FakeNotificationCenterClient.swift UcapHutangTests/ReviewReminderSchedulerTests.swift
git commit -m "feat: schedule a silent daily reminder while review drafts are pending"
```

---

### Task 3: Notification tap routing through `AppDelegate`

**Files:**
- Create: `UcapHutang/App/AppDelegate.swift`
- Replace: `UcapHutang/UcapHutangApp.swift`
- Create: `UcapHutangTests/AppDelegateNotificationRoutingTests.swift`

**Interfaces:**
- Consumes: `AppRouter`, `AppTab` (P4); `AppContainer.router` (P4).
- Produces: `final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate` with `var router: AppRouter?` and `func handleNotification(destination: String?)`. A `"review"` destination selects `.review`, including when it arrives before `router` is attached (cold launch).

- [ ] **Step 1: Write the failing test**

Create `UcapHutangTests/AppDelegateNotificationRoutingTests.swift`:

```swift
import XCTest
@testable import UcapHutang

@MainActor
final class AppDelegateNotificationRoutingTests: XCTestCase {
    func testReviewDestinationOpensReviewTabEvenBeforeRouterIsAttached() {
        let delegate = AppDelegate()

        delegate.handleNotification(destination: "review")
        let router = AppRouter()
        router.selectedTab = .ledger
        delegate.router = router
        XCTAssertEqual(router.selectedTab, .review)

        router.selectedTab = .capture
        delegate.handleNotification(destination: "something-else")
        XCTAssertEqual(router.selectedTab, .capture)

        delegate.handleNotification(destination: "review")
        XCTAssertEqual(router.selectedTab, .review)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run the single test class command with `<Class>` = `AppDelegateNotificationRoutingTests`.

Expected: `error: cannot find 'AppDelegate' in scope`, `** TEST FAILED **`.

- [ ] **Step 3: Implement**

Create `UcapHutang/App/AppDelegate.swift`:

```swift
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
```

Replace the entire content of `UcapHutang/UcapHutangApp.swift` with:

```swift
import SwiftUI

@main
struct UcapHutangApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var container = AppContainer.makeDefault()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(container)
                .onAppear {
                    appDelegate.router = container.router
                }
        }
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run the single test class command with `<Class>` = `AppDelegateNotificationRoutingTests`. Expected: `Executed 1 test, with 0 failures`.

Run the full test command. Expected: `Executed 109 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add UcapHutang/App/AppDelegate.swift UcapHutang/UcapHutangApp.swift UcapHutangTests/AppDelegateNotificationRoutingTests.swift
git commit -m "feat: route review reminder taps to the Review tab"
```

---

### Task 4: Notification primer (onboarding)

**Files:**
- Create: `UcapHutang/Features/Onboarding/ViewModels/NotificationPrimerViewModel.swift`
- Create: `UcapHutang/Features/Onboarding/Views/NotificationPrimerView.swift`
- Create: `UcapHutangTests/TestDoubles/FakeReminderScheduler.swift`
- Create: `UcapHutangTests/NotificationPrimerViewModelTests.swift`

**Interfaces:**
- Consumes: `ReminderScheduling`, `ReminderSettingsStore`, `NotificationAccess` (Tasks 1–2); `InMemoryReminderSettingsStore` (Task 1).
- Produces:
  - `@Observable final class NotificationPrimerViewModel` — `init(scheduler: any ReminderScheduling, settingsStore: any ReminderSettingsStore)`, `isFinished: Bool`, `allow() async`, `later() async`, `static func shouldShow(scheduler:settingsStore:) async -> Bool`.
  - `struct NotificationPrimerView: View` — `init(scheduler:settingsStore:)`; dismisses itself when finished.
  - Test double `FakeReminderScheduler(access:accessAfterRequest:)` with `requestAccessCallCount`, `syncCallCount`.

- [ ] **Step 1: Write the failing tests**

Create `UcapHutangTests/TestDoubles/FakeReminderScheduler.swift`:

```swift
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
```

Create `UcapHutangTests/NotificationPrimerViewModelTests.swift`:

```swift
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
```

- [ ] **Step 2: Run to verify it fails**

Run the single test class command with `<Class>` = `NotificationPrimerViewModelTests`.

Expected: `error: cannot find 'NotificationPrimerViewModel' in scope`, `** TEST FAILED **`.

- [ ] **Step 3: Implement**

Create `UcapHutang/Features/Onboarding/ViewModels/NotificationPrimerViewModel.swift`:

```swift
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
```

Create `UcapHutang/Features/Onboarding/Views/NotificationPrimerView.swift`:

```swift
import SwiftUI

struct NotificationPrimerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: NotificationPrimerViewModel

    init(scheduler: any ReminderScheduling, settingsStore: any ReminderSettingsStore) {
        _viewModel = State(initialValue: NotificationPrimerViewModel(scheduler: scheduler, settingsStore: settingsStore))
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bell.badge")
                .font(.largeTitle)
                .imageScale(.large)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("Pengingat Review")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text("Kami akan mengingatkanmu setiap hari pukul 20.00 untuk meninjau catatan hasil rekaman. Jam pengingat bisa kamu ubah kapan saja di Pengaturan.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task { await viewModel.allow() }
                } label: {
                    Text("Izinkan Notifikasi")
                        .font(.headline)
                        .foregroundStyle(Color(.systemBackground))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.primary)

                Button("Nanti Saja") {
                    Task { await viewModel.later() }
                }
                .font(.body)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(24)
        .onChange(of: viewModel.isFinished) { _, finished in
            if finished { dismiss() }
        }
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run the single test class command with `<Class>` = `NotificationPrimerViewModelTests`. Expected: `Executed 3 tests, with 0 failures`.

Run the full test command. Expected: `Executed 112 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add UcapHutang/Features/Onboarding UcapHutangTests/TestDoubles/FakeReminderScheduler.swift UcapHutangTests/NotificationPrimerViewModelTests.swift
git commit -m "feat: add first-launch notification primer"
```

---

### Task 5: Pengaturan screen

**Files:**
- Create: `UcapHutang/Features/Pengaturan/ViewModels/PengaturanViewModel.swift`
- Create: `UcapHutang/Features/Pengaturan/Views/PengaturanView.swift`
- Create: `UcapHutangTests/PengaturanViewModelTests.swift`

**Interfaces:**
- Consumes: `ReminderScheduling`, `ReminderSettingsStore`, `ReminderSettings`, `NotificationAccess`; `FakeReminderScheduler`, `InMemoryReminderSettingsStore`.
- Produces:
  - `@Observable final class PengaturanViewModel` — `init(scheduler: any ReminderScheduling, settingsStore: any ReminderSettingsStore, calendar: Calendar = .current)`; `isReminderEnabled: Bool`, `reminderTime: Date`, `access: NotificationAccess`; `refreshAccess() async`, `setReminderEnabled(_:) async`, `setReminderTime(_:) async`, `requestAccess() async`.
  - `struct PengaturanView: View` — `init(scheduler:settingsStore:)`.

- [ ] **Step 1: Write the failing tests**

Create `UcapHutangTests/PengaturanViewModelTests.swift`:

```swift
import XCTest
@testable import UcapHutang

@MainActor
final class PengaturanViewModelTests: XCTestCase {
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    func testTurningRemindersOffPersistsAndSyncs() async {
        let scheduler = FakeReminderScheduler(access: .authorized)
        let store = InMemoryReminderSettingsStore()
        let viewModel = PengaturanViewModel(scheduler: scheduler, settingsStore: store, calendar: utcCalendar)
        XCTAssertTrue(viewModel.isReminderEnabled)

        await viewModel.setReminderEnabled(false)

        XCTAssertFalse(viewModel.isReminderEnabled)
        XCTAssertFalse(store.settings.isEnabled)
        XCTAssertEqual(scheduler.syncCallCount, 1)
    }

    func testChangingTheTimePersistsHourAndMinuteAndSyncs() async {
        let scheduler = FakeReminderScheduler(access: .authorized)
        let store = InMemoryReminderSettingsStore()
        let calendar = utcCalendar
        let viewModel = PengaturanViewModel(scheduler: scheduler, settingsStore: store, calendar: calendar)
        let sevenThirty = calendar.date(from: DateComponents(year: 2026, month: 9, day: 12, hour: 7, minute: 30))!

        await viewModel.setReminderTime(sevenThirty)

        XCTAssertEqual(store.settings.hour, 7)
        XCTAssertEqual(store.settings.minute, 30)
        XCTAssertEqual(calendar.component(.hour, from: viewModel.reminderTime), 7)
        XCTAssertEqual(calendar.component(.minute, from: viewModel.reminderTime), 30)
        XCTAssertEqual(scheduler.syncCallCount, 1)
    }

    func testRequestingAccessUpdatesStatusAndSyncs() async {
        let scheduler = FakeReminderScheduler(access: .notDetermined, accessAfterRequest: .authorized)
        let viewModel = PengaturanViewModel(scheduler: scheduler, settingsStore: InMemoryReminderSettingsStore(), calendar: utcCalendar)
        await viewModel.refreshAccess()
        XCTAssertEqual(viewModel.access, .notDetermined)

        await viewModel.requestAccess()

        XCTAssertEqual(viewModel.access, .authorized)
        XCTAssertEqual(scheduler.requestAccessCallCount, 1)
        XCTAssertEqual(scheduler.syncCallCount, 1)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run the single test class command with `<Class>` = `PengaturanViewModelTests`.

Expected: `error: cannot find 'PengaturanViewModel' in scope`, `** TEST FAILED **`.

- [ ] **Step 3: Implement**

Create `UcapHutang/Features/Pengaturan/ViewModels/PengaturanViewModel.swift`:

```swift
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
```

Create `UcapHutang/Features/Pengaturan/Views/PengaturanView.swift`:

```swift
import SwiftUI

struct PengaturanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: PengaturanViewModel

    init(scheduler: any ReminderScheduling, settingsStore: any ReminderSettingsStore) {
        _viewModel = State(initialValue: PengaturanViewModel(scheduler: scheduler, settingsStore: settingsStore))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Pengingat Review", isOn: Binding(
                        get: { viewModel.isReminderEnabled },
                        set: { isOn in Task { await viewModel.setReminderEnabled(isOn) } }
                    ))

                    DatePicker(
                        "Jam",
                        selection: Binding(
                            get: { viewModel.reminderTime },
                            set: { date in Task { await viewModel.setReminderTime(date) } }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .environment(\.locale, Locale(identifier: "id_ID"))
                    .disabled(!viewModel.isReminderEnabled)

                    switch viewModel.access {
                    case .authorized:
                        EmptyView()
                    case .notDetermined:
                        Button("Izinkan Notifikasi") {
                            Task { await viewModel.requestAccess() }
                        }
                    case .denied:
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notifikasi dimatikan untuk UcapHutang.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button("Buka Pengaturan") {
                                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                    openURL(url)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Pengingat")
                } footer: {
                    Text("Kamu akan diingatkan setiap hari pada jam ini selama masih ada catatan yang perlu ditinjau.")
                }
            }
            .navigationTitle("Pengaturan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Selesai") { dismiss() }
                }
            }
            .task { await viewModel.refreshAccess() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await viewModel.refreshAccess() }
                }
            }
        }
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run the single test class command with `<Class>` = `PengaturanViewModelTests`. Expected: `Executed 3 tests, with 0 failures`.

Run the full test command. Expected: `Executed 115 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add UcapHutang/Features/Pengaturan UcapHutangTests/PengaturanViewModelTests.swift
git commit -m "feat: add Pengaturan screen for the review reminder"
```

---

### Task 6: Wire reminders, primer, and settings into the app

**Files:**
- Replace: `UcapHutang/App/AppContainer.swift`
- Replace: `UcapHutang/App/RootTabView.swift`
- Replace: `UcapHutang/Features/Review/Views/ReviewListView.swift`

**Interfaces:**
- Consumes: everything from Tasks 1–5; `AppContainer` (P4), `RootTabView` (P5), `ReviewListView` (P3).
- Produces:
  - `AppContainer.reminderSettings: any ReminderSettingsStore`, `AppContainer.reminderScheduler: any ReminderScheduling`; `init(repository:extraction:contacts:reminderSettings:reminderScheduler:router:makeSpeechTranscriber:storageErrorMessage:)`.
  - `ReviewListView.init(repository: any TransactionRepository, onSelect: @escaping (UUID) -> Void, onOpenSettings: @escaping () -> Void)`.

- [ ] **Step 1: Replace `AppContainer.swift`**

Replace the entire content of `UcapHutang/App/AppContainer.swift` with:

```swift
import Foundation
import Observation
import SwiftData

@Observable
final class AppContainer {
    let repository: any TransactionRepository
    let extraction: any DraftExtracting
    let capture: any VoiceCapturing
    let contacts: any ContactsProviding
    let reminderSettings: any ReminderSettingsStore
    let reminderScheduler: any ReminderScheduling
    let router: AppRouter
    let makeSpeechTranscriber: @MainActor () -> any SpeechTranscribing
    let storageErrorMessage: String?

    init(
        repository: any TransactionRepository,
        extraction: any DraftExtracting,
        contacts: any ContactsProviding,
        reminderSettings: any ReminderSettingsStore,
        reminderScheduler: any ReminderScheduling,
        router: AppRouter = AppRouter(),
        makeSpeechTranscriber: @escaping @MainActor () -> any SpeechTranscribing = { SpeechRecognizer() },
        storageErrorMessage: String? = nil
    ) {
        self.repository = repository
        self.extraction = extraction
        self.capture = VoiceCapturePipeline(extraction: extraction, repository: repository)
        self.contacts = contacts
        self.reminderSettings = reminderSettings
        self.reminderScheduler = reminderScheduler
        self.router = router
        self.makeSpeechTranscriber = makeSpeechTranscriber
        self.storageErrorMessage = storageErrorMessage
    }

    static func makeDefault() -> AppContainer {
        let schema = Schema(versionedSchema: SchemaV2.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let contacts = SystemContactsProvider()
        let extraction = QwenDraftExtractionService(llmClient: MLXQwenClient())
        let reminderSettings = UserDefaultsReminderSettingsStore()
        let notificationCenter = SystemNotificationCenterClient()
        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: UcapHutangMigrationPlan.self,
                configurations: config
            )
            let repo = SwiftDataTransactionRepository(modelContainer: container)
            return AppContainer(
                repository: repo,
                extraction: extraction,
                contacts: contacts,
                reminderSettings: reminderSettings,
                reminderScheduler: ReviewReminderScheduler(
                    center: notificationCenter,
                    settingsStore: reminderSettings,
                    repository: repo
                )
            )
        } catch {
            let fallbackRepo = InMemoryTransactionRepository()
            // SwiftData has no migration-specific error type. If a store file already exists,
            // the failure happened while opening/migrating existing data.
            let storeExists = FileManager.default.fileExists(atPath: config.url.path)
            let message = storeExists
                ? "Migrasi data ke versi terbaru gagal. Demi mencegah kehilangan data, pencatatan dinonaktifkan sementara. Tutup lalu buka kembali aplikasi. Detail: \(error.localizedDescription)"
                : "Penyimpanan lokal tidak dapat dibuka. Demi mencegah kehilangan data, pencatatan dinonaktifkan sementara. Tutup lalu buka kembali aplikasi. Detail: \(error.localizedDescription)"
            return AppContainer(
                repository: fallbackRepo,
                extraction: extraction,
                contacts: contacts,
                reminderSettings: reminderSettings,
                reminderScheduler: ReviewReminderScheduler(
                    center: notificationCenter,
                    settingsStore: reminderSettings,
                    repository: fallbackRepo
                ),
                storageErrorMessage: message
            )
        }
    }
}
```

- [ ] **Step 2: Add the gear button to the Review list**

Replace the entire content of `UcapHutang/Features/Review/Views/ReviewListView.swift` with:

```swift
import SwiftUI

struct ReviewListView: View {
    @State private var viewModel: ReviewListViewModel
    let onSelect: (UUID) -> Void
    let onOpenSettings: () -> Void

    init(
        repository: any TransactionRepository,
        onSelect: @escaping (UUID) -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: ReviewListViewModel(repository: repository))
        self.onSelect = onSelect
        self.onOpenSettings = onOpenSettings
    }

    var body: some View {
        NavigationStack {
            FilteredCardListView(
                title: "Catatan hasil rekaman perlu dicek sebelum masuk buku",
                items: viewModel.filteredDrafts,
                selectedFilter: viewModel.selectedFilter,
                onSelectFilter: { viewModel.selectFilter($0) },
                onSelectItem: { onSelect($0) },
                emptyState: {
                    AppEmptyState(
                        icon: "checkmark.circle",
                        title: "Belum ada yang perlu ditinjau",
                        message: "Hasil pencatatan suara yang belum dikonfirmasi akan muncul di sini."
                    )
                },
                cardContent: { item in
                    ReviewCardView(item: item)
                }
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Pengaturan")
                }
            }
            .task { await viewModel.loadDrafts() }
            .refreshable { await viewModel.loadDrafts() }
            .onReceive(NotificationCenter.default.publisher(for: .transactionRepositoryDidChange)) { _ in
                Task { await viewModel.loadDrafts() }
            }
            .alert("Gagal Memuat Draft", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Terjadi kesalahan.")
            }
        }
    }
}

#Preview {
    ReviewListView(
        repository: InMemoryTransactionRepository(seedDrafts: [
            TransactionDraft(
                flow: .personal,
                type: .piutang,
                title: "Makan siang",
                totalAmount: 15_000,
                participants: [TransactionParticipant(name: "Dito", shareAmount: 15_000)],
                rawTranscript: "Dito pinjam 15 ribu buat makan siang"
            )
        ]),
        onSelect: { _ in },
        onOpenSettings: {}
    )
}
```

- [ ] **Step 3: Replace `RootTabView.swift`**

Replace the entire content of `UcapHutang/App/RootTabView.swift` with:

```swift
import SwiftUI

struct IdentifiableUUID: Identifiable, Equatable {
    let id: UUID
    init(_ id: UUID) { self.id = id }
}

struct RootTabView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.scenePhase) private var scenePhase
    @State private var reviewDraftItem: IdentifiableUUID?
    @State private var selectedCaptureFlow: CaptureFlow?
    @State private var pendingReviewCount = 0
    @State private var isShowingSettings = false
    @State private var isShowingNotificationPrimer = false

    var body: some View {
        @Bindable var router = container.router

        TabView(selection: $router.selectedTab) {
            Tab("Review", systemImage: "doc.badge.clock", value: AppTab.review) {
                ReviewListView(
                    repository: container.repository,
                    onSelect: { draftID in reviewDraftItem = IdentifiableUUID(draftID) },
                    onOpenSettings: { isShowingSettings = true }
                )
            }
            .badge(pendingReviewCount)

            Tab("Catat", systemImage: "mic.fill", value: AppTab.capture) {
                CatatFlowChooserView(router: container.router) { flow in
                    selectedCaptureFlow = flow
                }
            }

            Tab("Riwayat", systemImage: "book.closed", value: AppTab.ledger) {
                LedgerListView(repository: container.repository, contacts: container.contacts)
            }
        }
        .sensoryFeedback(.success, trigger: container.router.savedBannerID) { _, newValue in
            newValue != nil
        }
        .task {
            await refreshPendingReviewCount()
            isShowingNotificationPrimer = await NotificationPrimerViewModel.shouldShow(
                scheduler: container.reminderScheduler,
                settingsStore: container.reminderSettings
            )
            await container.reminderScheduler.sync()
        }
        .onReceive(NotificationCenter.default.publisher(for: .transactionRepositoryDidChange)) { _ in
            Task {
                await refreshPendingReviewCount()
                await container.reminderScheduler.sync()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await container.reminderScheduler.sync() }
            }
        }
        .sheet(item: $reviewDraftItem) { item in
            NavigationStack {
                ReviewDetailView(draftID: item.id, repository: container.repository, contacts: container.contacts)
            }
        }
        .sheet(item: $selectedCaptureFlow) { flow in
            CatatView(flow: flow, container: container)
        }
        .sheet(isPresented: $isShowingSettings) {
            PengaturanView(scheduler: container.reminderScheduler, settingsStore: container.reminderSettings)
        }
        .fullScreenCover(isPresented: $isShowingNotificationPrimer) {
            NotificationPrimerView(scheduler: container.reminderScheduler, settingsStore: container.reminderSettings)
        }
    }

    private func refreshPendingReviewCount() async {
        pendingReviewCount = (try? await container.repository.pendingDraftCount()) ?? 0
    }
}
```

- [ ] **Step 4: Build and test**

Run the full test command. Expected: `Executed 115 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add UcapHutang/App/AppContainer.swift UcapHutang/App/RootTabView.swift UcapHutang/Features/Review/Views/ReviewListView.swift
git commit -m "feat: wire review reminder, notification primer and Pengaturan into the app"
```

- [ ] **Step 6: Simulator primer smoke check**

```bash
xcodebuild build -project UcapHutang.xcodeproj -scheme UcapHutang -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath build/DerivedData -quiet
xcrun simctl boot "iPhone 17" 2>/dev/null || true
xcrun simctl uninstall "iPhone 17" AdhiKrisna.UcapHutang 2>/dev/null || true
xcrun simctl install "iPhone 17" build/DerivedData/Build/Products/Debug-iphonesimulator/UcapHutang.app
xcrun simctl launch "iPhone 17" AdhiKrisna.UcapHutang
sleep 6
xcrun simctl io "iPhone 17" screenshot build/p6-primer.png
```

Expected: no `error:` lines; `build/p6-primer.png` shows the "Pengingat Review" primer (a fresh install has never decided notification permission). Report the screenshot path to the developer.

- [ ] **Step 7: Hand the device checklist to the developer**

Send this checklist verbatim and wait for confirmation before starting P7:

1. Delete and reinstall the app → the "Pengingat Review" primer appears once. **Nanti Saja** closes it without a system prompt; relaunching does not show it again.
2. Reinstall again → **Izinkan Notifikasi** shows the system prompt.
3. Review tab → gear button (VoiceOver: "Pengaturan") → Pengaturan shows "Pengingat Review" ON and "Jam" 20.00.
4. With at least one draft pending, set "Jam" to 2 minutes from now, lock the phone, and wait → one **silent** notification "Ada catatan yang perlu ditinjau / Kamu punya N catatan yang belum disimpan ke Riwayat."
5. Tap the notification → the app opens on the Review tab.
6. While the app is open at the reminder time → no banner appears; the notification is in Notification Center.
7. Save or delete every draft, set the time 2 minutes ahead again → no notification arrives.
8. Turn "Pengingat Review" OFF with drafts pending → no notification arrives.
9. In iOS Settings, turn notifications off for UcapHutang → Pengaturan shows "Notifikasi dimatikan untuk UcapHutang." with **Buka Pengaturan**.

## Phase exit checklist

- [ ] `git status --porcelain` shows only `?? .xcede/` and `?? xcede.yml`.
- [ ] `git log --oneline -6` shows the six P6 commits.
- [ ] Full test command: `Executed 115 tests, with 0 failures`, `** TEST SUCCEEDED **`.
- [ ] The developer confirmed the Task 6 checklist.
