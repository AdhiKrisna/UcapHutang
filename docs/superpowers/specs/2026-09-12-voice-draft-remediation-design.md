# UcapHutang Voice → Draft → Riwayat Remediation — Design Spec

- **Date:** 2026-09-12
- **Branch:** `fix/all`
- **Status:** Approved in brainstorming (all 8 design sections approved by the product owner)
- **Executor:** Gemini 3.7 Flash via a CLI on the developer's Mac (has terminal access; can run `xcodebuild` and the iOS Simulator)
- **Supersedes:** the "contact linking is optional" decisions in `docs/PROJECT_REMEDIATION_PLAN.md` (P0 §3, P1 Review §2, acceptance criterion "Contact linking remains optional"). Everything else in that document still stands unless contradicted here.

---

## 1. Product flow (source of truth)

1. **Catat** — the user picks *Utang/Piutang* (Personal) or *Split Bill*, records their voice.
2. The recording is processed in **three stages** and saved as a **Draft**:
   1. Speech → text with `SFSpeechRecognizer` (`id-ID`).
   2. Text → structured output with the local LLM (Qwen3-0.6B-4bit via MLX).
   3. Structured output → `TransactionDraft` → persisted with SwiftData.
3. The Catat sheet closes and the user is told the result is in the **Review** tab (formerly "Draft"). The user is **not** taken to the review form.
4. Every day at a **user-chosen time** (default 20:00), while at least one draft is pending, a local notification reminds the user to check drafts.
5. The user opens a draft from the **Review** tab, completes it (every person **must be linked to an iPhone contact**), and taps **Simpan Catatan**.
6. A valid draft becomes confirmed ledger entries shown in **Riwayat** (the "catatan" menu).

## 2. Bug being fixed

> In Catat, tapping "Simpan Catatan" shows the "lengkapi data" alert, but the data is still saved to history with a person who is not linked to a contact.

**Required behavior:** a draft can only be confirmed when **every** participant is linked to an iPhone contact (`contactIdentifier != nil`). When it is not, nothing is written to the ledger; the draft stays in the Review tab.

**Root causes found in code:**

| # | Finding | Evidence |
|---|---------|----------|
| F1 | Neither the UI validation nor the domain validator requires a linked contact. | `Features/Review/ReviewDraftViewModel.swift:20-66`, `Domain/Models/DraftValidator.swift:14-55` |
| F2 | Two different Review screens exist. The Draft-tab one (`DraftReviewView`) never loads the real draft: it shows hard-coded mock values (Rp150.000, "Pinjam buat makan siang", "Dito") and on save **overwrites** the real draft's type/amount/title with those values and confirms it with no validation. Its `errorMessage` is never shown. | `App/RootTabView.swift:47`, `Features/Draft/Views/DraftReviewView.swift:8-24`, `Features/Draft/ViewModels/DraftReviewViewModel.swift:48-76,136-158` |
| F3 | The Draft-tab contact picker lists **mock** contacts and can "create" a contact with a random UUID. | `Features/Draft/ViewModels/DraftContactPickerViewModel.swift:36-37,103-110`, `Features/Draft/Models/DraftUIModels.swift:164-173` |
| F4 | The Catat-path Review shows Waktu, Nominal, Deskripsi and person name as read-only; the editable field builders exist but are dead code, so the user cannot fix what the alert asks for. | `Features/Review/ReviewDraftView.swift:128-159` (used) vs `:270-465` (unused) |
| F5 | Ledger identity is `contactIdentifier ?? name.lowercased()`, so unlinked names silently become ledger people. | `Domain/Repositories/SwiftDataTransactionRepository.swift:193-205`, `Domain/Repositories/TransactionRepository.swift:113-124` |

The fix enforces the rule **at the domain/repository boundary** (so no UI path can bypass it) and replaces both Review screens with one correct screen.

## 3. Decisions log

All decisions below were made explicitly by the product owner on 2026-09-12.

| Topic | Decision |
|-------|----------|
| Draft after failed save | Stays in the Review tab (formerly "Draft"). Only confirmation into Riwayat is blocked. |
| Split Bill contacts | **All** participants must be linked. |
| Contact source | **iPhone Contacts only.** No "create new contact", no app-local people. |
| "Catatan" menu | The **Riwayat** tab (`Features/Ledger` today). |
| Contacts permission | **Required.** `denied`, `restricted` and `limited` all block linking; show an explanation + "Buka Pengaturan". |
| When to ask Contacts permission | When the user taps **Hubungkan** (just-in-time). |
| Existing unlinked people in Riwayat | **Must be linked.** Badge on the person, "Catat Bayar" and "Ingatkan" blocked until linked. |
| Linking to a contact that already has history | **Merge with confirmation**; balances add up. |
| After Catat processing | Close the sheet + tell the user it is in Review. |
| Reminder timing | **User-chosen time**, default **20:00**, active immediately once notification permission is granted; the user is told the time can be changed. |
| Reminder settings location | New **Pengaturan** screen opened from a **gear button in the Review tab** toolbar. |
| Notification permission timing | **First app launch**, preceded by an explanation (pre-permission) screen. |
| Reminder repetition | **Daily** at the chosen time **while drafts exist**; stops when Draft is empty. |
| Review design source of truth | The **Draft-tab design** (`DraftReviewView`, `SmartContactCardView`, `DraftContactPickerSheet`). These types are renamed to `Review*` (§5.3). |
| Auto-link | **Never automatic.** A single matching contact is shown as a suggestion that the user must confirm. |
| Editable in Review | Waktu, Nominal, Deskripsi, Jenis, people (add/remove/change), per-person amount for Split Bill (equal or custom). |
| Transcript / extraction warnings in Review | **Not shown** (still stored as evidence). |
| Split "Bagi Rata" | A toggle "Saya ikut dihitung"; default **ON** (`total ÷ (friends + 1)`); OFF = `total ÷ friends`. |
| Split "Custom" | `total = Σ friends' shares`; Nominal is read-only; the user's share is Rp0; the toggle is hidden. |
| Rounding remainder | Given to friends in list order (current `SplitCalculationEngine` behavior). |
| "Hapus catatan ini" | **Permanent delete** (draft + participants). |
| Closing Review without saving | Edits are **auto-saved back to the draft** (it stays in Review); no confirmation dialog. |
| Reminder while the app is open | **No banner**; delivered to Notification Center only. |
| Former "Draft" tab | Renamed **"Review"**, icon `doc.badge.clock`; every user-facing "Draft" text is replaced (§7.4, §8.1, §10). |
| Draft/Review feature folders | The content of `Features/Draft` moves into `Features/Review` and replaces it; `Features/Draft` is deleted. |
| Feature type names | Feature-layer `Draft*` types are renamed to `Review*` (§5.3). Domain/data names (`TransactionDraft`, `DraftStatus`, `DraftValidator`, `DraftMapper`, repository methods) do not change. |
| Old Catat-path Review files | Moved to `Features/Review/Legacy/` in P1 (so P1 changes no behavior), deleted in P3. |
| Uncommitted change in `QwenOutputDecoder.swift` | Owned by the developer. Agents never touch it; P1 starts only after the developer has committed or discarded it. |
| "Ingatkan lewat iMessage" label | Renamed to **"Ingatkan lewat Pesan"**. |
| Linked contact later deleted from the iPhone | **Still treated as linked**; the stored name snapshot is shown. |
| Legacy `discarded` drafts | **Purged during the Schema V2 migration**; the `discarded` status is removed from code. |
| Speech privacy | `requiresOnDeviceRecognition` when the device supports it for `id-ID`; otherwise use Apple's server and tell the user. |
| LLM | Keep **Qwen3-0.6B-4bit MLX**. Harden, don't replace. |
| Folder structure | **Feature-first MVVM** (approach A, §5). |
| State management | Migrate `ObservableObject` → `@Observable`. |
| Feature naming | **Indonesian** feature folders (`Catat`, `Draft`, `Riwayat`, `Pengaturan`, `Onboarding`); domain types stay English. |
| HIG scope | **Audit every screen**, including Riwayat. |
| Testing | **TDD with XCTest** in the existing `UcapHutangTests` target. |
| Docs | Spec + plans in English under `docs/superpowers/`, committed to `fix/all`. |

## 4. Goals and non-goals

**Goals**

- Make it impossible to confirm a draft with an unlinked person, from any path.
- One Review screen that edits the real draft.
- A clean, documented three-stage voice pipeline with a pure, tested mapping stage.
- Daily draft reminders with an explicit settings screen.
- A consistent feature-first MVVM folder structure with `@Observable` ViewModels.
- HIG-compliant UI across all screens (target 10/10 on the HIG diagnostic).

**Non-goals (YAGNI)**

- Replacing Qwen or `SFSpeechRecognizer` (no Foundation Models, no `SpeechAnalyzer`).
- Showing transcripts or model warnings in Review.
- Switching a draft between Personal and Split Bill in Review (the capture flow stays authoritative).
- Writing to the iPhone Contacts database.
- App icon badge, swipe-to-delete on the Review list, export/import, iCloud sync.
- Pre-filling the SMS recipient from the linked contact in "Ingatkan".
- UI test target (not present today; manual device QA covers integration).

## 5. Architecture

### 5.1 Layers and dependency rule

```
View  ──>  ViewModel (@Observable, MainActor)  ──>  Domain protocols
                                                        ^
                              Data / Services implement them
App/AppContainer is the only place that creates concrete implementations.
```

- Views render state and forward intents. No parsing, inference, persistence, or permission logic.
- ViewModels depend only on `Domain` types and protocols. They must not `import SwiftData`, `Contacts`, `Speech`, `AVFoundation`, `MLX*`, `UserNotifications`, or `UIKit`. Views open URLs (iOS Settings via `UIApplication.openSettingsURLString`, `sms:`) through `@Environment(\.openURL)`; ViewModels only expose the `URL` to open.
- `Domain` has no framework imports beyond `Foundation`.
- `Data` and `Services` implement `Domain/Protocols`.
- The project already sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES`; do not add redundant `@MainActor` to types in the app target unless needed for clarity at a `nonisolated` boundary.
- The Xcode target uses **file-system-synchronized groups** (`PBXFileSystemSynchronizedRootGroup`). Moving/adding/removing files on disk updates the target automatically. **Do not edit `project.pbxproj` to move files.**

### 5.2 Target folder structure

```
UcapHutang/
├── App/
│   ├── UcapHutangApp.swift
│   ├── AppDelegate.swift              (UNUserNotificationCenterDelegate)
│   ├── AppContainer.swift             (composition root)
│   ├── AppRouter.swift                (selected tab, deep links from notifications)
│   ├── ContentView.swift
│   └── RootTabView.swift              (Tab API)
├── Core/
│   ├── DesignSystem/                  (AppDesignSystem.swift, FilteredCardListView, FilterSegmentBar)
│   ├── Extensions/                    (Int64+Rupiah.swift, Array+Safe.swift)
│   └── Utilities/                     (SplitCalculationEngine.swift)
├── Domain/
│   ├── Models/                        (TransactionModels.swift, ContactModels.swift, ReminderSettings.swift)
│   ├── Validation/                    (DraftValidator.swift)
│   └── Protocols/                     (TransactionRepository, ContactsProviding, SpeechTranscribing,
│                                       DraftExtracting, ReminderScheduling, ReminderSettingsStore)
├── Data/
│   └── Persistence/                   (SchemaV1.swift, SchemaV2.swift, UcapHutangMigrationPlan.swift,
│                                       SwiftDataTransactionRepository.swift, InMemoryTransactionRepository.swift,
│                                       UserDefaultsReminderSettingsStore.swift)
├── Services/
│   ├── Speech/                        (stage 1: SpeechRecognizer.swift)
│   ├── AI/                            (stage 2: MLXQwenClient, QwenPromptBuilder, QwenOutputDecoder,
│                                       TransactionDateResolver, QwenDraftExtractionService)
│   ├── Capture/                       (stage 3: DraftMapper.swift, VoiceCapturePipeline.swift)
│   ├── Contacts/                      (SystemContactsProvider.swift)
│   └── Notifications/                 (ReviewReminderScheduler.swift)
├── Resources/Models/Qwen3-0.6B-4bit/  (unchanged, git-ignored)
└── Features/
    ├── Catat/       Views/ ViewModels/ Components/
    ├── Review/      Views/ ViewModels/ Components/ Models/   (+ Legacy/ only between P1 and P3)
    ├── Riwayat/     Views/ ViewModels/ Components/ Models/
    ├── Pengaturan/  Views/ ViewModels/
    └── Onboarding/  Views/ ViewModels/
```

A feature only gets a subfolder when it has at least one file for it. `Models/` inside a feature holds **UI-only** models (e.g. `ReviewItemUIModel`); domain models live in `Domain/Models`.

### 5.3 File mapping from today

| Today | Target |
|-------|--------|
| `ContentView.swift` | `App/ContentView.swift` |
| `Features/Components.swift` | `Core/DesignSystem/FilteredCardListView.swift` (previews move with it) |
| `Domain/Models/SwiftDataEntities.swift` | `Data/Persistence/SchemaV1.swift` + `SchemaV2.swift` |
| `Domain/Models/DraftValidator.swift` | `Domain/Validation/DraftValidator.swift` |
| `Domain/Repositories/TransactionRepository.swift` | protocol + errors → `Domain/Protocols/TransactionRepository.swift`; `InMemoryTransactionRepository` → `Data/Persistence/` |
| `Domain/Repositories/SwiftDataTransactionRepository.swift` | `Data/Persistence/` |
| `Core/Utilities/QwenOutputDecoder.swift`, `TransactionDateResolver.swift` | `Services/AI/` |
| `Services/AI/DraftExtractionService.swift` | split into `QwenPromptBuilder.swift`, `QwenDraftExtractionService.swift` (stage 2) and `Services/Capture/DraftMapper.swift` (stage 3) |
| `Services/Contacts/ContactResolutionService.swift` | `Services/Contacts/SystemContactsProvider.swift` implementing `ContactsProviding` (no singleton) |
| `Features/Catat/*.swift` | `Features/Catat/Views/`, `Features/Catat/ViewModels/` |
| `Features/Draft/**` | `Features/Review/**` (replaces the old folder; `DraftListView.swift` goes to `Views/`) with these renames: `DraftListView`→`ReviewListView`, `DraftListViewModel`→`ReviewListViewModel`, `DraftReviewView`→`ReviewDetailView`, `DraftReviewViewModel`→`ReviewDetailViewModel`, `DraftCardView`→`ReviewCardView`, `DraftContactPickerSheet`→`ReviewContactPickerSheet`, `DraftContactPickerViewModel`→`ReviewContactPickerViewModel`, `DraftUIModels.swift`→`ReviewUIModels.swift` (`DraftItemUIModel`→`ReviewItemUIModel`, `DraftParticipantUIModel`→`ReviewParticipantUIModel`, `DraftFilterType`→`ReviewFilterType`, `DraftMockData`→`ReviewMockData` until P3). `SmartContactCardView` and `SplitParticipantRow` keep their names. |
| `Features/Review/ReviewDraftView.swift`, `ReviewDraftViewModel.swift`, `ContactPickerSheet.swift` (old Catat-path Review) | `Features/Review/Legacy/` in P1; **deleted** in P3 |
| `AppTab.draft` | `AppTab.review` |
| `Features/Ledger/**` | `Features/Riwayat/**` (type names may keep `Ledger` prefix; folder is renamed) |

**Delete in P1:** unused `*ViewModelProtocol` protocols, `import Combine` in ViewModels, `PreviewData` in `AppContainer.swift` if unused, and every local `formatRupiah(_:)` duplicate in favor of `Int64.rupiahFormatted`.

**Delete in P3 (together with `Features/Review/Legacy/`):** `extension Int: @retroactive Identifiable` (today `Features/Review/ReviewDraftView.swift:468`), the dead view builders in `ReviewDraftView`, and `ReviewMockData` from production code (sample values move into `#Preview` blocks or test fixtures). These stay until P3 because the legacy screen and the mock-backed review form still use them, and P1 must not change behavior.

### 5.4 Composition root and injection

- `AppContainer` becomes `@Observable` and owns: `repository`, `contacts: ContactsProviding`, `makeSpeechTranscriber: () -> any SpeechTranscribing` (a fresh recognizer per Catat session), `extraction: DraftExtracting`, `capturePipeline: VoiceCapturePipeline`, `reminderScheduler: ReminderScheduling`, `reminderSettings: ReminderSettingsStore`, `router: AppRouter`.
- `UcapHutangApp` holds it with `@State` and injects it with `.environment(container)`.
- Feature views construct their ViewModel in `init` from injected dependencies and hold it with `@State`.
- The storage-failure path in `AppContainer.makeDefault()` is unchanged in behavior (blocking error screen).

## 6. Domain and data

### 6.1 Domain model changes

```swift
struct TransactionParticipant { id, name, contactIdentifier: String?, shareAmount: Int64, itemTitle: String?, notes: String? }  // unchanged fields

struct TransactionDraft {
    // existing fields…
    var includesUser: Bool = true          // NEW — only meaningful for .splitBill + .equal
    // `status` keeps only .needsReview and .confirmed
}

enum DraftStatus: String { case needsReview, confirmed }   // `discarded` REMOVED

struct LedgerEntry {
    // existing fields…
    var contactIdentifier: String?          // NEW — nil means a legacy unlinked person
}

struct PersonLedgerSummary {
    // existing fields…
    var contactIdentifier: String?          // NEW
    var isLinked: Bool { contactIdentifier != nil }
}

struct ContactRef: Hashable, Sendable {     // NEW, Domain/Models/ContactModels.swift
    let identifier: String
    let displayName: String
    let phoneNumber: String?
}

enum ContactsAccess: Sendable { case notDetermined, authorized, denied }  // limited/restricted map to .denied

protocol ContactsProviding: Sendable {                   // NEW, Domain/Protocols/ContactsProviding.swift
    func access() -> ContactsAccess
    func requestAccess() async -> ContactsAccess
    func search(name: String) async -> [ContactRef]       // [] when access() != .authorized
    func contacts(withIdentifiers ids: [String]) async -> [ContactRef]  // skips identifiers not found
}

struct ReminderSettings: Equatable, Sendable {   // NEW
    var isEnabled: Bool = true
    var hour: Int = 20
    var minute: Int = 0
}
```

### 6.2 Validation (the bug fix)

`DraftValidator.validateForConfirmation(_:)` keeps all current rules and adds:

- Every participant must have a non-empty `contactIdentifier`. Error message (Indonesian): `"Hubungkan setiap orang ke kontak sebelum menyimpan."`
- Split Bill custom: `totalAmount` must equal `Σ shareAmount` (the ViewModel keeps them in sync; the validator guards it).
- Split Bill equal: shares must equal `SplitCalculationEngine.calculateEqualShares(total, count)` for `count = friends + (includesUser ? 1 : 0)`, taking the first `friends` values.

Add `DraftValidator.issues(for:) -> [DraftValidationIssue]` returning **all** problems (for the alert list and per-card labels). `validateForConfirmation` throws the first issue. The Review ViewModel uses `issues(for:)`; repositories call `validateForConfirmation`. There is **one** rule set.

```swift
enum DraftValidationIssue: Equatable {
    case amountNotPositive
    case titleMissing
    case directionMissing
    case participantsMissing
    case participantNameMissing(participantID: UUID)
    case participantNotLinked(participantID: UUID)
    case duplicateParticipant
    case personalRequiresExactlyOne
    case shareNotPositive(participantID: UUID)
    case sharesExceedTotal
    case sharesDoNotMatchTotal
    var message: String { /* Indonesian, field-specific */ }
}
```

Duplicate detection uses `contactIdentifier` when present, otherwise the normalized name.

### 6.3 Ledger identity

- New charges: `personID = contactIdentifier` (always non-nil after validation), `personName = contact display name`, `contactIdentifier = contactIdentifier`.
- Legacy unlinked entries: `personID = lowercased name`, `contactIdentifier = nil`.
- Summaries group by `personID`; `contactIdentifier` is the first non-nil value in the group.
- If a linked contact was later deleted from the iPhone, Riwayat keeps showing the stored `personName` snapshot; the entry is still considered linked.

### 6.4 Repository API

```swift
protocol TransactionRepository: Sendable {
    func draftsNeedingReview() async throws -> [TransactionDraft]
    func pendingDraftCount() async throws -> Int                       // NEW (badge + reminder)
    func draft(id: UUID) async throws -> TransactionDraft?
    func saveDraft(_ draft: TransactionDraft) async throws
    func deleteDraft(id: UUID) async throws                            // NEW, replaces discardDraft; hard delete + cascade
    func confirmDraft(_ draft: TransactionDraft) async throws          // validates first; idempotent (unchanged)
    func ledgerEntries() async throws -> [LedgerEntry]
    func linkedContactIdentifiers() async throws -> [String]           // NEW, distinct, for "Kontak yang pernah dicatat"
    func linkPerson(personID: String, to contact: ContactRef) async throws  // NEW
    func recordPayment(for person: PersonLedgerSummary, amount: Int64, date: Date, notes: String?) async throws
}

enum RepositoryError: LocalizedError {
    case invalidAmount, paymentExceedsBalance, noOutstandingBalance
    case personNotLinked          // NEW — recordPayment on an unlinked person
    case personNotFound           // NEW — linkPerson with unknown personID
}
```

`linkPerson(personID:to:)`:

1. Fetch all entries where `personID == oldID`. If none → `personNotFound`.
2. For each: `personID = contact.identifier`, `personName = contact.displayName`, `contactIdentifier = contact.identifier`.
3. Also set `personName = contact.displayName` on entries that already had `personID == contact.identifier` (so a merged person has one name).
4. One `context.save()`, then post `.transactionRepositoryDidChange`.

Whether a merge will happen is decided **before** calling this (the ViewModel checks if the contact already has entries and shows the confirmation dialog). The repository itself always performs the move.

`recordPayment` throws `personNotLinked` when the person's entries have `contactIdentifier == nil`.

`InMemoryTransactionRepository` implements the same contract for tests and previews.

### 6.5 SwiftData versioning and migration

- `SchemaV1` (version 1.0.0): **exact copy** of today's `SDTransactionParticipant`, `SDTransactionDraft`, `SDLedgerEntry`.
- `SchemaV2` (version 2.0.0):
  - `SDTransactionDraft.includesUser: Bool = true`
  - `SDLedgerEntry.contactIdentifier: String? = nil`
- `UcapHutangMigrationPlan`: one `.custom(fromVersion: SchemaV1.self, toVersion: SchemaV2.self, willMigrate: nil, didMigrate:)` stage whose `didMigrate`:
  1. Deletes every `SDTransactionDraft` with `statusRaw == "discarded"` (participants cascade).
  2. Builds `linked = Set(all SDTransactionParticipant.contactIdentifier where non-nil)`.
  3. For each `SDLedgerEntry`: `contactIdentifier = linked.contains(personID) ? personID : nil`.
  4. Saves.
- App code uses `typealias SDTransactionDraft = SchemaV2.SDTransactionDraft` (etc.).
- `AppContainer.makeDefault()` creates `ModelContainer(for: Schema(versionedSchema: SchemaV2.self), migrationPlan: UcapHutangMigrationPlan.self, configurations: …)`.

**Risk:** attaching a `VersionedSchema` to a store created without one. Mitigation: a test creates an **on-disk** store in a temp directory with `SchemaV1` models, inserts linked/unlinked/discarded fixtures, closes it, reopens with `SchemaV2` + the migration plan, and asserts the three migration rules. The developer must also run the app once on a device that already has data before merging P2.

### 6.6 Split Bill math (single implementation)

A pure helper in `Core/Utilities/SplitCalculationEngine.swift`:

```swift
static func shares(total: Int64, friendCount: Int, includesUser: Bool) -> [Int64]
// equal: calculateEqualShares(total, friendCount + (includesUser ? 1 : 0)).prefix(friendCount)
static func customTotal(_ shares: [Int64]) -> Int64?   // nil on overflow
```

Used by `DraftMapper`, `ReviewDetailViewModel`, and `DraftValidator`. No other code divides totals.

## 7. Voice pipeline (three stages)

### 7.1 Stage 1 — Speech (`Services/Speech`)

```swift
protocol SpeechTranscribing: AnyObject {
    var state: SpeechRecognizerState { get }      // idle, listening, finalizing, failed(String)
    var liveTranscript: String { get }
    var usesOnDeviceRecognition: Bool { get }
    func start() async throws                     // requests mic + speech permission just-in-time
    func finish() async -> String                 // waits for isFinal, bounded timeout (existing 750 ms)
    func cancel()
}
```

- Set `request.requiresOnDeviceRecognition = true` when `speechRecognizer.supportsOnDeviceRecognition` is `true`; expose it via `usesOnDeviceRecognition`.
- Permission errors are typed (`SpeechPermissionError.microphoneDenied`, `.speechDenied`, `.restricted`) so the Catat UI can show "Buka Pengaturan".
- Keep the existing contextual vocabulary.
- Known limitation (documented, not fixed): server-based recognition has a per-request duration limit imposed by Apple.

### 7.2 Stage 2 — LLM extraction (`Services/AI`)

```swift
protocol DraftExtracting: Sendable {
    func extract(flow: CaptureFlow, transcript: String, referenceDate: Date) async -> ExtractionResult
}

struct ExtractionResult: Sendable {
    let output: CaptureOutput          // decoded (possibly empty) structure
    let resolvedDate: Date
    let rawModelResponse: String?
    let warnings: [String]
}
```

- `QwenDraftExtractionService` = today's `HybridQwenExtractionService` logic up to (and including) decoding and date resolution. It **never throws** for model/decoder failures: it falls back to decoding `"{}"` and records a warning (today's behavior). It throws only for an empty transcript.
- `QwenPromptBuilder`, `MLXQwenClient`, `QwenOutputDecoder`, `TransactionDateResolver` keep their current contracts. Existing `QwenMigrationTests` must keep passing (update only the type name they instantiate).

### 7.3 Stage 3 — Mapping + persistence (`Services/Capture`)

```swift
enum DraftMapper {
    static func makeDraft(flow: CaptureFlow, transcript: String, result: ExtractionResult, createdAt: Date) -> TransactionDraft
}
```

Rules:

- `status = .needsReview`, `contactIdentifier = nil` for every participant.
- Personal: one participant with the model's person name (may be empty), `shareAmount = amount ?? 0`, `type` from direction (`unknown` stays `unknown`).
- Split Bill: participants from `receivables` (name + item + amount); `splitMethod = basis == .custom ? .custom : .equal`; `includesUser = true`.
  - Equal: `shareAmount` from `SplitCalculationEngine.shares(total:friendCount:includesUser: true)`. The model's `split_count` is **not** used for shares.
  - Custom: `totalAmount = customTotal(shares)` when every share > 0, otherwise the model's total (or 0).
- `rawTranscript`, `rawModelResponse`, `reviewWarnings`, `transactionDate` copied from inputs.

```swift
final class VoiceCapturePipeline {
    func process(flow: CaptureFlow, transcript: String) async throws -> UUID
    // 1) extraction.extract  2) DraftMapper.makeDraft  3) repository.saveDraft  4) reminderScheduler.sync()
}
```

Re-entrancy and cancellation guards currently in `CatatViewModel` (active request UUID, task cancellation on disappear) stay, moved to the ViewModel that calls the pipeline.

### 7.4 Catat screen behavior

- Model readiness gate on the flow chooser stays.
- Recording screen: accessible record/stop `Button` (label "Mulai merekam"/"Berhenti merekam", value = state), "Ulangi", live transcript, progress while finalizing/processing.
- If `usesOnDeviceRecognition == false`: footnote "Ucapan diproses oleh server Apple."
- Permission denied: inline message + "Buka Pengaturan" (`UIApplication.openSettingsURLString`).
- Empty transcript: "Suara tidak terdeteksi. Silakan coba lagi." (unchanged).
- On success:
  1. Dismiss the Catat sheet.
  2. `UINotificationFeedbackGenerator().notificationOccurred(.success)` (via `.sensoryFeedback(.success, trigger:)`).
  3. Post an accessibility announcement: "Tersimpan ke Review".
  4. Show a non-blocking banner at the top of the Catat tab: **"Tersimpan ke Review"** with a **"Lihat"** button (switches `AppRouter` to the Review tab). Auto-hides after 4 seconds; stays while VoiceOver focus is on it. Respects Reduce Motion (fade instead of slide).
  5. The Review tab shows `.badge(pendingDraftCount)`.
- The user stays on the Catat tab.

## 8. Review (single screen, Draft-tab design)

Location: `Features/Review/Views/ReviewDetailView.swift`, `Features/Review/ViewModels/ReviewDetailViewModel.swift`, `Features/Review/Components/SmartContactCardView.swift`, `Features/Review/Views/ReviewContactPickerSheet.swift`, `Features/Review/ViewModels/ReviewContactPickerViewModel.swift`.

Entry points: tapping a card in the Review tab (and, indirectly, a reminder notification that opens the Review tab). Presented as a sheet with its own `NavigationStack` (as today in `RootTabView`).

### 8.1 Loading

- `init(draftID:)` → `.task { await viewModel.load() }` → loads the draft from the repository. **No default/mock values.**
- States: loading (`ProgressView`), loaded, not found (`ContentUnavailableView` with the text "Catatan ini tidak ditemukan." + "Tutup").
- After load, compute contact suggestions (8.3).

### 8.2 Fields

| Field | Control | Notes |
|-------|---------|-------|
| Waktu | `DatePicker` (date + hour/minute) | Label text uses locale `id_ID`; no hand-built "Hari ini" string that ignores the date. |
| Nominal | `TextField` with `.number` format, `.keyboardType(.numberPad)` | Read-only (displayed as text) when Split + Custom. Changing it recomputes equal shares. |
| Deskripsi | `TextField` | Maps to `title`. |
| Jenis (Personal) | Segmented `Picker`: Utang / Piutang | `unknown` shows no selection and produces a validation issue. |
| Metode bagi (Split) | Segmented `Picker`: Bagi Rata / Custom | |
| Saya ikut dihitung (Split + Bagi Rata) | `Toggle`, default ON | Recomputes shares. Hidden in Custom. |
| Orang / Peserta | `SmartContactCardView` per participant | Personal: exactly one card, no "+ Tambah orang". Split: "+ Tambah orang" opens the picker in multi-select; swipe or a remove button deletes a participant. |
| Bagian per peserta (Split) | Text (equal) or number `TextField` (custom) | Custom edits update `totalAmount = Σ shares`. |

A summary row for Split shows friends' total, the user's share (equal + ON only), and the transaction total.

### 8.3 Contact card states

| State | Text | Actions |
|-------|------|---------|
| `unlinked` | `<name>` · "Belum terhubung" | **Hubungkan** |
| `suggestion(ContactRef)` | `<name>` · "Mirip kontak “<displayName>”" | **Ya, hubungkan** · **Bukan, pilih lain** |
| `linked(ContactRef)` | `<displayName>` · "Terhubung ke kontak" | **Ganti** |

- A suggestion is computed **only** if `contacts.access() == .authorized` and `contacts.search(name: participant.name)` returns **exactly one** contact. It never counts as linked.
- When validation fails, an unlinked/suggestion card additionally shows the text **"Wajib dihubungkan"** with a `exclamationmark.circle` symbol in `.orange` (meaning is carried by the text, not color).
- Buttons have ≥ 44×44 pt hit targets and accessibility labels that include the person's name.

### 8.4 Linking flow

1. User taps **Hubungkan / Bukan, pilih lain / Ganti / + Tambah orang**.
2. `contacts.access()`:
   - `.notDetermined` → `await contacts.requestAccess()`; re-evaluate.
   - `.denied` (includes `restricted` and `limited`) → alert **"Akses Kontak Diperlukan"**, message "UcapHutang perlu akses penuh ke Kontak agar setiap catatan terhubung ke orang yang tepat.", buttons **"Buka Pengaturan"** / **"Nanti"**. Stop.
   - `.authorized` → present `ReviewContactPickerSheet`.
3. Picker (native `List` + `.searchable`, prefilled with the participant's name when relinking):
   - Section **"Kontak yang pernah dicatat"**: contacts whose identifiers are in `repository.linkedContactIdentifiers()`, resolved through `ContactsProviding`; missing contacts are skipped.
   - Section **"Kontak di iPhone"**: search results from `ContactsProviding`.
   - No "Buat kontak baru" row. Empty search: `ContentUnavailableView.search`.
   - Single-select (Personal / relink): tapping a row selects and dismisses. Multi-select (Split add): checkmarks + "Selesai".
   - Toolbar: "Batal" (cancellation) and, for multi-select, "Selesai" (confirmation). No custom chevrons.
4. Selecting a contact sets `participant.name = contact.displayName`, `participant.contactIdentifier = contact.identifier`. Selecting a contact already used by another participant shows "Orang ini sudah ada di catatan." and does nothing.

### 8.5 Save and delete

- **Simpan Catatan** (primary, bottom, full-width, system prominent style):
  1. `issues = DraftValidator.issues(for: draft)`.
  2. If not empty → alert **"Data Belum Lengkap"** listing `issue.message` bullets; mark cards (8.3). **No repository call.**
  3. Else → `repository.confirmDraft(draft)` → success haptic → dismiss.
  4. Repository error → alert with the error's Indonesian message; draft unchanged.
  - The button is disabled while saving (with a `ProgressView`).
- **Hapus catatan ini** (destructive text button) → `confirmationDialog` "Hapus catatan ini?" / "Catatan dan transkripnya akan dihapus permanen." / **Hapus** (destructive) / **Batal** → `repository.deleteDraft(id:)` → dismiss.
- **Closing without saving** (toolbar **"Tutup"** in the cancellation placement, or swipe-down): if the ViewModel is dirty, its edits are written back with `repository.saveDraft(draft)` — status stays `needsReview`, no validation, no ledger write — and the Review list refreshes. No confirmation dialog. `ReviewDetailView` calls `viewModel.persistEditsIfNeeded()` from `.onDisappear` inside a `Task` (the task retains the ViewModel until the write finishes). The method is idempotent and a no-op after a successful save or delete, or when nothing changed.

## 9. Riwayat (legacy unlinked people)

- `PersonCardRow`: when `!person.isLinked`, show "Belum terhubung ke kontak" (secondary text + `person.crop.circle.badge.exclamationmark`).
- `PersonLedgerDetailView` when `!person.isLinked`:
  - An inset card: "Hubungkan orang ini ke kontak untuk mencatat pembayaran atau mengirim pengingat." + **"Hubungkan ke Kontak"**.
  - "Catat Bayar" and "Ingatkan" are `.disabled(true)` with `accessibilityHint` explaining why.
- Linking uses the same permission flow (8.4 step 2) and a single-select picker.
- After a contact is picked, if `ledgerEntries` already contain `personID == contact.identifier`: `confirmationDialog` **"Gabungkan riwayat?"** / "Riwayat “<old name>” akan digabung dengan “<contact name>”. Saldo akan dijumlahkan." / **Gabungkan** / **Batal**. Otherwise link directly.
- Then `repository.linkPerson(personID:to:)`; the detail view switches to the new `personID` and reloads.
- `recordPayment` enforces `personNotLinked` at the repository.
- "Ingatkan lewat iMessage" is relabeled **"Ingatkan lewat Pesan"** (it opens the Messages composer via `sms:`).

## 10. Reminders, onboarding, settings

### 10.1 Settings store

```swift
protocol ReminderSettingsStore: AnyObject {
    var settings: ReminderSettings { get set }          // persisted in UserDefaults
    var hasSeenNotificationPrimer: Bool { get set }
}
```

UserDefaults keys: `reminder.isEnabled` (default `true`), `reminder.hour` (default `20`), `reminder.minute` (default `0`), `onboarding.notificationPrimerSeen` (default `false`).

### 10.2 Scheduler

```swift
enum NotificationAccess: Sendable { case notDetermined, authorized, denied }

protocol ReminderScheduling: Sendable {
    func access() async -> NotificationAccess
    func requestAccess() async -> NotificationAccess
    func sync() async        // reads settings + pendingDraftCount, (re)schedules or removes
}
```

`ReviewReminderScheduler` wraps `UNUserNotificationCenter` behind a small protocol (`NotificationCenterClient`) so it can be unit-tested with a fake.

`sync()`:

1. Remove the pending request with identifier `review-reminder`.
2. If `settings.isEnabled && access == .authorized && pendingDraftCount > 0`: add a request with `UNCalendarNotificationTrigger(dateMatching: DateComponents(hour:, minute:), repeats: true)`.
   - Title: "Ada catatan yang perlu ditinjau"
   - Body: "Kamu punya \(count) catatan yang belum disimpan ke Riwayat."
   - `userInfo["destination"] = "review"`.
3. Otherwise leave nothing scheduled.

Call `sync()` on: `.transactionRepositoryDidChange`, settings change, scene phase `.active`, and after the onboarding permission result.

Known limitation (documented): the count in the body is the count at the last sync. It stays accurate because drafts only change through the app, which always triggers a sync.

### 10.3 Notification handling

- `AppDelegate` (`@UIApplicationDelegateAdaptor`) sets itself as `UNUserNotificationCenter.current().delegate`.
- `willPresent` → `[.list]` (no banner while the app is in the foreground; the reminder still lands in Notification Center).
- `didReceive` with `destination == "review"` → `AppRouter.selectedTab = .review`.

### 10.4 Onboarding (notification primer)

- Shown once on launch when `hasSeenNotificationPrimer == false` and `access == .notDetermined`, as a `.fullScreenCover` over `RootTabView`.
- Content: `bell.badge` symbol, title **"Pengingat Review"**, body **"Kami akan mengingatkanmu setiap hari pukul 20.00 untuk meninjau catatan hasil rekaman. Jam pengingat bisa kamu ubah kapan saja di Pengaturan."**, primary **"Izinkan Notifikasi"** → system prompt, secondary **"Nanti Saja"** → no system prompt.
- Either button sets `hasSeenNotificationPrimer = true`, dismisses, then calls `sync()`. It is never shown again at launch.

### 10.5 Pengaturan screen

- Opened from a `gearshape` toolbar button (label "Pengaturan") in the Review tab; presented as a sheet with `NavigationStack`, title "Pengaturan", "Selesai" confirmation button.
- `Form`:
  - Section **"Pengingat"**: `Toggle("Pengingat Review")`; `DatePicker("Jam", displayedComponents: .hourAndMinute)` (disabled when the toggle is off); footer "Kamu akan diingatkan setiap hari pada jam ini selama masih ada catatan yang perlu ditinjau."
  - Notification status row when not authorized:
    - `.notDetermined` → "Izinkan Notifikasi" button → `requestAccess()`.
    - `.denied` → "Notifikasi dimatikan untuk UcapHutang." + "Buka Pengaturan" button.
- Every change persists immediately and calls `sync()`.

## 11. HIG audit (all screens)

Current estimate: **5/10** on the HIG quick diagnostic (safe areas OK; Dark Mode, Dynamic Type, touch targets, VoiceOver and native-idiom points lost). Target: **10/10**.

| Area | Current problem (evidence) | Required fix |
|------|----------------------------|--------------|
| Typography | Hard-coded sizes: `.system(size: 26, …)` in `Components.swift:69`, `LedgerListView.swift:19`; `.system(size: 32, …)` in `PersonLedgerDetailView.swift:38`; `.system(size: 9, …)` in `DraftCardView.swift:92`; `.system(size: 34, …)` in `CatatView.swift:96` | Semantic text styles; `@ScaledMetric` for custom sizes (avatars, record control). |
| Color / Dark Mode | `Color(red: 1.0, green: 0.96, blue: 0.88)` in `PersonLedgerDetailView.swift:53`; `.white` on accent in `ContactPickerSheet.swift:52`; raw `Color.green/.red` | Semantic colors only; add named colors with light/dark variants to the asset catalog if a brand tint is needed; route through `AppColors`. |
| Navigation | Custom chevron back buttons: `DraftReviewView.swift:183-189`, `ReviewDraftView.swift:76-101`, `DraftContactPickerSheet.swift:104-110` | System back; sheets use text "Batal"/"Selesai"/"Tutup". |
| Tab bar | `.tabItem` in `RootTabView.swift`; Draft tab icon `exclamationmark.triangle` implies an error | `Tab` API with `.badge`; tabs **Review** (`doc.badge.clock`, formerly "Draft"), **Catat** (`mic.fill`, unchanged), **Riwayat** (`book.closed`, unchanged). |
| Touch targets | Card buttons with 6 pt vertical padding (`SmartContactCardView.swift:45-48,71-74`); filter buttons 38 pt (`Components.swift:23`) | ≥ 44×44 pt. |
| Search | Custom floating field with a non-functional mic icon (`LedgerListView.swift:120-139`) | `.searchable(text:prompt:)`; remove the mic icon. |
| Controls | Custom `Text` buttons with manual backgrounds for primary actions | `.buttonStyle(.borderedProminent)` / `.bordered` / plain text, `.controlSize(.large)` for primary. |
| Accessibility | No labels on record control, avatars, amounts, filter state | Labels, values, hints; `.accessibilityElement(children: .combine)` for cards; `.isSelected` trait on filters; hide decorative avatars. |
| Dynamic Type | Fixed 250 pt record circle, `lineLimit(1)` + `minimumScaleFactor` on balances | Layouts verified at `accessibility5`; allow wrapping. |
| Motion | Implicit animations without Reduce Motion checks | Respect `accessibilityReduceMotion`. |
| Formatting | Three copies of `formatRupiah` with `NumberFormatter` | `Int64.rupiahFormatted` only. |
| Honesty | "Ingatkan lewat iMessage" opens SMS | "Ingatkan lewat Pesan". |

Each screen must be checked in Light, Dark, and the largest accessibility text size in Xcode Previews, and with VoiceOver on a device.

## 12. Error handling summary

| Situation | Behavior |
|-----------|----------|
| Storage cannot open | Existing blocking `ContentUnavailableView` (unchanged). |
| Migration fails | Same blocking screen, message includes "migrasi data". No silent fallback. |
| Model missing | Flow chooser disabled with readiness text (unchanged). |
| Mic/Speech permission denied | Inline message + "Buka Pengaturan". |
| LLM/decoder failure | Draft saved with empty/partial fields; warning stored; user completes it in Review. |
| Save draft fails after extraction | Alert "Gagal Memproses" with the error message (current behavior); the user can record again. |
| Contacts access not full | Alert with "Buka Pengaturan"; no linking. |
| Validation fails | Alert listing issues + card labels; nothing written. |
| Confirm fails in repository | Alert with repository message; draft unchanged. |
| Notification access denied | Pengaturan shows status + "Buka Pengaturan"; scheduler schedules nothing. |
| Link/merge fails | Alert; no partial writes (single save). |

## 13. Testing strategy

- Framework: **XCTest**, target `UcapHutangTests`, **test-first** for every production behavior.
- Command (verified 2026-09-12, 14 tests passing on `fix/all` @ `d765ef8`):

  ```bash
  xcodebuild test -project UcapHutang.xcodeproj -scheme UcapHutang -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'
  ```

- Unit tests (no real Contacts/Speech/MLX/notifications):
  - `DraftValidator`: unlinked personal/split participants rejected; all existing rules; custom/equal share checks; `issues(for:)` returns every issue.
  - `SplitCalculationEngine.shares`: includesUser on/off, remainder distribution, overflow.
  - `DraftMapper`: personal/split mapping, `includesUser = true`, `contactIdentifier == nil`, ignores `split_count`.
  - Repositories (`InMemoryTransactionRepository` and `SwiftDataTransactionRepository` with `isStoredInMemoryOnly: true`): confirm with unlinked participant throws and writes no ledger entry (**regression test for the bug**); idempotent confirm; `deleteDraft` removes draft + participants; `pendingDraftCount`; `linkedContactIdentifiers`; `linkPerson` move + merge + name unification; `recordPayment` on unlinked throws.
  - Migration V1 → V2 on an on-disk temp store (§6.5).
  - ViewModels with fakes (`FakeContactsProvider`, `FakeReminderScheduler`, `FakeSpeechTranscriber`, `StubDraftExtractor`): Review load/no-mock, suggestion only on exactly one match and authorized access, denied access shows settings alert, save blocked with issues and no repository call, delete; closing a dirty Review calls `saveDraft` (never `confirmDraft`) and a clean one calls nothing; Catat success sets banner + triggers router badge; Riwayat merge dialog decision; Pengaturan persists and syncs; Onboarding sets flag.
  - `ReviewReminderScheduler` with `FakeNotificationCenterClient`: schedules only when enabled + authorized + count > 0; removes otherwise; trigger components match settings; repeats is `true`.
  - `QwenMigrationTests` keep passing.
- Manual device QA checklist (in the final plan): on-device vs server speech notice, MLX inference, Contacts permission states (not determined / denied / limited / full), notification primer, reminder delivery at a time set 2 minutes ahead, notification tap → Review tab, VoiceOver run-through of Catat → Review list → review form → Riwayat, Dark Mode, largest text size.

## 14. Delivery phases

One implementation plan per phase, executed in order. Each phase ends with a green `xcodebuild test` and a commit.

| Phase | Scope | Key exit criteria |
|-------|-------|-------------------|
| **P0** | Bug guard: `DraftValidator` requires `contactIdentifier`; regression tests on both repositories. | Confirming an unlinked draft throws and writes nothing. (Temporary: the mock Draft-tab Review silently fails to save until P3.) |
| **P1** | **Precondition:** `UcapHutang/Core/Utilities/QwenOutputDecoder.swift` has no uncommitted changes (the developer resolves it first; the agent stops otherwise). Folder restructure (§5.2–5.3) incl. `Features/Draft` → `Features/Review` with `Review*` renames and the old Catat-path Review files → `Features/Review/Legacy/`; `@Observable` migration; `Tab` API with the "Review" tab label and `doc.badge.clock` icon; P1 deletions (§5.3). **No behavior change** apart from the tab label/icon. | App builds; all tests green; no `ObservableObject`, `@Published`, `@StateObject`, `@EnvironmentObject` or `import Combine` outside `Features/Review/Legacy/`; no files left in old folders; `project.pbxproj` unchanged. |
| **P2** | Domain model changes (§6.1), `DraftValidationIssue`, split helper, `SchemaV1/V2` + migration plan, repository API (§6.4). | Migration test + repository tests green. |
| **P3** | Unified Review (§8) incl. `ContactsProviding`, picker, permission flow; delete `Features/Review/Legacy/`, `Int: @retroactive Identifiable`, and `ReviewMockData`. | ViewModel tests green; manual check of all card states. |
| **P4** | Pipeline split (§7), `VoiceCapturePipeline`, Catat close + banner + badge, on-device speech. | Mapper/pipeline tests green; Qwen tests green. |
| **P5** | Riwayat link/merge/blocking (§9). | Link/merge/payment-guard tests green. |
| **P6** | Reminder scheduler, onboarding primer, Pengaturan, notification routing (§10). | Scheduler + settings tests green; device reminder check. |
| **P7** | HIG audit fixes across all screens (§11) + manual QA checklist. | Checklist completed; HIG diagnostic 10/10. |

## 15. Acceptance criteria

1. No code path can create a ledger entry for a participant without `contactIdentifier`.
2. After a failed save the draft is still in the Review tab and Riwayat is unchanged.
3. Opening a draft shows its real stored values; there are no mock values in production code.
4. Split Bill equal shares honor the "Saya ikut dihitung" toggle; custom total always equals the sum of friends' shares.
5. "Hapus catatan ini" physically deletes the draft and its participants; legacy discarded drafts are gone after migration.
6. Legacy unlinked people are labeled in Riwayat, cannot record payments or send reminders, and can be linked/merged with confirmation.
7. After recording, the Catat sheet closes, the user is told the result is in Review, and the Review tab badge shows the pending count.
8. With notifications allowed and at least one draft, exactly one repeating notification is scheduled at the configured time (default 20:00); none when Draft is empty or reminders are off.
9. The notification primer appears once on first launch, explains the 20:00 default and that it can be changed.
10. Folder structure matches §5.2; ViewModels use `@Observable` and import no system frameworks other than `Foundation`/`Observation`.
11. All screens pass the HIG checks in §11.
12. `xcodebuild test` passes after every phase.
13. Closing Review without saving keeps the user's edits in the draft and never writes to Riwayat.
