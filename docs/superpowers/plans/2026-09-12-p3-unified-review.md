# P3 — Unified Review with Mandatory Contact Linking Implementation Plan

> **For agentic workers (Gemini 3.7 Flash):** Execute the tasks in order, one step at a time. Steps use checkbox (`- [ ]`) syntax — tick each one as you finish it. When a step gives a complete file, replace the **entire** file with it. Never skip a "run the test and confirm it fails" step. If an actual result differs from the "Expected" text, stop and report instead of improvising.

**Goal:** Replace the mock-backed review form and the legacy Catat review with one Review screen that loads the real draft, lets the user edit every approved field, links every person to an iPhone contact (with a permission flow and confirm-only suggestions), and can only confirm a fully valid draft.

**Architecture:** `ReviewDetailViewModel` owns an editable copy of `TransactionDraft`, recalculates Split Bill shares through `SplitCalculationEngine`, asks `DraftValidator.issues(for:)` before calling the repository, and talks to Contacts only through the `ContactsProviding` protocol (`SystemContactsProvider` in the app, `FakeContactsProvider` in tests). The contact picker has its own ViewModel. The legacy review screen and `ContactResolutionService` are deleted; Catat temporarily pushes the new `ReviewDetailView` until P4 replaces that with close + banner.

**Tech Stack:** SwiftUI (iOS 26.5), Observation, Contacts framework, SwiftData (via repository), XCTest.

**Spec:** `docs/superpowers/specs/2026-09-12-voice-draft-remediation-design.md` (§3, §6.1–6.2, §8, §11, §14 P3).

## Global Constraints

- Work on branch `fix/all`. **P0, P1 and P2 must be finished**; the developer must have confirmed the P2 device migration check. Suite at start: 53 tests passing.
- **Never stage `.xcede/` or `xcede.yml`.** Always `git add` explicit paths (or `git mv`/`git rm`); never `git add -A`, `git add .`, or `git commit -a`.
- Do not edit `UcapHutang.xcodeproj/project.pbxproj`.
- Build settings in effect (do not change): `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_VERSION = 5.0`.
- ViewModels import only `Foundation` and `Observation`. Views open URLs with `@Environment(\.openURL)`.
- Contacts access: `denied`, `restricted` **and** `limited` all count as denied. Ask for access only when the user taps a linking action. Never auto-link: a single matching contact is only a suggestion.
- Use SwiftUI semantic text styles (`.body`, `.subheadline`, `.footnote`, `.headline`) and system colors in every view you write in this phase; interactive controls must be at least 44 pt tall.
- Exact user-facing copy (Indonesian) for this phase:

  | Where | Text |
  |-------|------|
  | Navigation title | `Review Catatan` |
  | Close button | `Tutup` |
  | Not found / load error | `Catatan ini tidak ditemukan.` |
  | Field labels | `Waktu`, `Nominal`, `Deskripsi`, `Jenis`, `Metode bagi`, `Orang` |
  | Segments | `Utang`, `Piutang` / `Bagi Rata`, `Custom` |
  | Toggle | `Saya ikut dihitung` |
  | Deskripsi placeholder | `Deskripsi transaksi` |
  | Share row label / placeholder | `Nominal bagian` |
  | Split summary rows | `Bagian teman`, `Bagian kamu`, `Total transaksi` |
  | Add participant | `+ Tambah orang` |
  | Card subtitles | `Belum terhubung`, `Mirip kontak “<nama kontak>”`, `Terhubung ke kontak` |
  | Card buttons | `Hubungkan`, `Ya, hubungkan`, `Bukan, pilih lain`, `Ganti` |
  | Card VoiceOver labels | `Hubungkan <nama> ke kontak`, `Hubungkan ke <nama kontak>`, `Pilih kontak lain untuk <nama>`, `Ganti kontak <nama>` |
  | Required marker | `Wajib dihubungkan` |
  | Blank name | `Belum ada nama` |
  | Context menu / VoiceOver action | `Hapus dari catatan` |
  | Primary button | `Simpan Catatan` |
  | Delete button | `Hapus catatan ini` |
  | Delete dialog | title `Hapus catatan ini?`, message `Catatan dan transkripnya akan dihapus permanen.`, buttons `Hapus` / `Batal` |
  | Incomplete alert | title `Data Belum Lengkap`, message = bullet list of distinct issue messages, button `Periksa Lagi` |
  | Contacts access alert | title `Akses Kontak Diperlukan`, message `UcapHutang perlu akses penuh ke Kontak agar setiap catatan terhubung ke orang yang tepat.`, buttons `Buka Pengaturan` / `Nanti` |
  | Duplicate contact alert | title `Orang ini sudah ada di catatan.`, button `OK` |
  | Save failure alert | title `Data Belum Bisa Disimpan`, message = error message, button `OK` |
  | Delete failure alert | title `Catatan Belum Bisa Dihapus`, message = error message, button `OK` |
  | Picker | title `Hubungkan ke kontak`, search prompt `Cari kontak`, sections `Kontak yang pernah dicatat` / `Kontak di iPhone`, buttons `Batal` / `Selesai` |

- Full test command:

  ```bash
  xcodebuild test -project UcapHutang.xcodeproj -scheme UcapHutang -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | grep -E "Test Case '.*' (passed|failed)|error:|Executed [0-9]+ tests|TEST SUCCEEDED|TEST FAILED"
  ```

- Single test class command (replace `<Class>`):

  ```bash
  xcodebuild test -project UcapHutang.xcodeproj -scheme UcapHutang -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:UcapHutangTests/<Class> 2>&1 | grep -E "Test Case '.*' (passed|failed)|error:|Executed [0-9]+ tests|TEST SUCCEEDED|TEST FAILED"
  ```

Expected test totals: start 53 → Task 1: 57 → Task 2: 58 → Task 3: 61 → Task 4: 78.

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `UcapHutang/Domain/Validation/DraftValidator.swift` | Modify | Split Bill share-consistency rules. |
| `UcapHutang/Domain/Models/ContactModels.swift` | Replace | `ContactRef` + `ContactsAccess`. |
| `UcapHutang/Domain/Protocols/ContactsProviding.swift` | Create | Contacts boundary protocol. |
| `UcapHutang/Services/Contacts/SystemContactsProvider.swift` | Create | `CNContactStore` implementation. |
| `UcapHutang/Services/Contacts/ContactResolutionService.swift` | Delete (Task 4) | Replaced. |
| `UcapHutang/App/AppContainer.swift` | Replace | Adds `contacts`. |
| `UcapHutang/App/RootTabView.swift` | Modify | Passes `contacts` to Review. |
| `UcapHutang/Features/Catat/Views/CatatView.swift` | Modify | Temporary push of new `ReviewDetailView`. |
| `UcapHutang/Features/Review/Models/ReviewUIModels.swift` | Replace | List item, card state, picker request, alert. |
| `UcapHutang/Features/Review/ViewModels/ReviewListViewModel.swift` | Replace | Real data only; approved blank-name copy. |
| `UcapHutang/Features/Review/ViewModels/ReviewDetailViewModel.swift` | Replace | Editing, linking, validation, save/delete/persist. |
| `UcapHutang/Features/Review/ViewModels/ReviewContactPickerViewModel.swift` | Replace | Recent + iPhone contacts, search, multi-select. |
| `UcapHutang/Features/Review/Views/ReviewListView.swift` | Replace | Non-optional repository; preview with in-memory data. |
| `UcapHutang/Features/Review/Views/ReviewDetailView.swift` | Replace | Review form. |
| `UcapHutang/Features/Review/Views/ReviewContactPickerSheet.swift` | Replace | Picker UI. |
| `UcapHutang/Features/Review/Components/ReviewCardView.swift` | Replace | Preview without mock enum. |
| `UcapHutang/Features/Review/Components/SmartContactCardView.swift` | Replace | Three card states + required marker. |
| `UcapHutang/Features/Review/Components/SplitParticipantRow.swift` | Replace | Per-participant share row. |
| `UcapHutang/Features/Review/Legacy/` | Delete (Task 4) | Legacy review. |
| `UcapHutangTests/TestDoubles/FakeContactsProvider.swift` | Create | Test double. |
| `UcapHutangTests/TestDoubles/SpyTransactionRepository.swift` | Create | Counts repository calls. |
| `UcapHutangTests/DraftValidatorShareRulesTests.swift` | Create | Share rules. |
| `UcapHutangTests/SystemContactsProviderTests.swift` | Create | Authorization mapping. |
| `UcapHutangTests/ReviewListViewModelTests.swift` | Create | List item mapping. |
| `UcapHutangTests/ReviewContactPickerViewModelTests.swift` | Create | Picker behavior. |
| `UcapHutangTests/ReviewDetailViewModelTests.swift` | Create | Review behavior. |

---

### Task 1: Split Bill share-consistency rules

**Files:**
- Modify: `UcapHutang/Domain/Validation/DraftValidator.swift` (the `case .splitBill:` branch inside `issues(for:)`)
- Create: `UcapHutangTests/DraftValidatorShareRulesTests.swift`

**Interfaces:**
- Consumes: `SplitCalculationEngine.shares(total:friendCount:includesUser:)`, `SplitCalculationEngine.customTotal(_:)`, `DraftValidationIssue.sharesDoNotMatchTotal` (all from P2).
- Produces: `DraftValidator.issues(for:)` now also returns `.sharesDoNotMatchTotal` when
  - `splitMethod == .custom` and `Σ shares < totalAmount`, or
  - `splitMethod` is `.equal` or `nil` and the shares differ from `SplitCalculationEngine.shares(total: totalAmount, friendCount: participants.count, includesUser: includesUser)`,
  - but only when no `.shareNotPositive` and no `.sharesExceedTotal` issue was already added for this draft.

- [ ] **Step 1: Write the failing tests**

Create `UcapHutangTests/DraftValidatorShareRulesTests.swift`:

```swift
import XCTest
@testable import UcapHutang

final class DraftValidatorShareRulesTests: XCTestCase {
    private func splitDraft(method: SplitMethod, includesUser: Bool, total: Int64, shares: [Int64]) -> TransactionDraft {
        TransactionDraft(
            flow: .splitBill,
            type: .splitBill,
            title: "Makan malam",
            totalAmount: total,
            splitMethod: method,
            includesUser: includesUser,
            participants: shares.enumerated().map { index, share in
                TransactionParticipant(name: "Teman \(index + 1)", contactIdentifier: "contact-\(index + 1)", shareAmount: share)
            },
            rawTranscript: "makan malam"
        )
    }

    func testCustomSharesBelowTotalAreRejected() {
        let draft = splitDraft(method: .custom, includesUser: true, total: 90_000, shares: [30_000, 30_000])
        XCTAssertEqual(DraftValidator.issues(for: draft), [.sharesDoNotMatchTotal])
    }

    func testCustomSharesEqualToTotalAreAccepted() {
        let draft = splitDraft(method: .custom, includesUser: true, total: 90_000, shares: [40_000, 50_000])
        XCTAssertEqual(DraftValidator.issues(for: draft), [])
    }

    func testEqualSharesMustMatchTheEngineWhenUserIsExcluded() {
        let draft = splitDraft(method: .equal, includesUser: false, total: 90_000, shares: [30_000, 30_000])
        XCTAssertEqual(DraftValidator.issues(for: draft), [.sharesDoNotMatchTotal])
    }

    func testEqualSharesMatchingTheEngineAreAccepted() {
        let draft = splitDraft(method: .equal, includesUser: false, total: 90_000, shares: [45_000, 45_000])
        XCTAssertEqual(DraftValidator.issues(for: draft), [])
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run the single test class command with `<Class>` = `DraftValidatorShareRulesTests`.

Expected: `testCustomSharesBelowTotalAreRejected` and `testEqualSharesMustMatchTheEngineWhenUserIsExcluded` **failed**; the other two **passed**; `** TEST FAILED **`.

- [ ] **Step 3: Implement**

In `UcapHutang/Domain/Validation/DraftValidator.swift`, replace this block:

```swift
        case .splitBill:
            if draft.type != .splitBill {
                issues.append(.splitTypeInvalid)
            }
            for participant in draft.participants where participant.shareAmount <= 0 {
                let name = participant.name.trimmingCharacters(in: .whitespacesAndNewlines)
                issues.append(.shareNotPositive(participantID: participant.id, name: name))
            }
            if let allocated = SplitCalculationEngine.customTotal(draft.participants.map(\.shareAmount)) {
                if allocated > draft.totalAmount {
                    issues.append(.sharesExceedTotal)
                }
            } else {
                issues.append(.sharesExceedTotal)
            }
        }
```

with:

```swift
        case .splitBill:
            if draft.type != .splitBill {
                issues.append(.splitTypeInvalid)
            }
            var hasShareProblem = false
            for participant in draft.participants where participant.shareAmount <= 0 {
                let name = participant.name.trimmingCharacters(in: .whitespacesAndNewlines)
                issues.append(.shareNotPositive(participantID: participant.id, name: name))
                hasShareProblem = true
            }
            let shares = draft.participants.map(\.shareAmount)
            if let allocated = SplitCalculationEngine.customTotal(shares) {
                if allocated > draft.totalAmount {
                    issues.append(.sharesExceedTotal)
                    hasShareProblem = true
                }
            } else {
                issues.append(.sharesExceedTotal)
                hasShareProblem = true
            }
            if !hasShareProblem && !draft.participants.isEmpty {
                let sharesMatch: Bool
                if draft.splitMethod == .custom {
                    sharesMatch = SplitCalculationEngine.customTotal(shares) == draft.totalAmount
                } else {
                    let expected = SplitCalculationEngine.shares(
                        total: draft.totalAmount,
                        friendCount: draft.participants.count,
                        includesUser: draft.includesUser
                    )
                    sharesMatch = shares == expected
                }
                if !sharesMatch {
                    issues.append(.sharesDoNotMatchTotal)
                }
            }
        }
```

- [ ] **Step 4: Run to verify it passes**

Run the single test class command with `<Class>` = `DraftValidatorShareRulesTests`. Expected: `Executed 4 tests, with 0 failures`.

Run the full test command. Expected: `Executed 57 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add UcapHutang/Domain/Validation/DraftValidator.swift UcapHutangTests/DraftValidatorShareRulesTests.swift
git commit -m "feat: require Split Bill shares to match the chosen split method"
```

---

### Task 2: Contacts boundary, system provider, and test doubles

**Files:**
- Replace: `UcapHutang/Domain/Models/ContactModels.swift`
- Create: `UcapHutang/Domain/Protocols/ContactsProviding.swift`
- Create: `UcapHutang/Services/Contacts/SystemContactsProvider.swift`
- Replace: `UcapHutang/App/AppContainer.swift`
- Create: `UcapHutangTests/TestDoubles/FakeContactsProvider.swift`
- Create: `UcapHutangTests/TestDoubles/SpyTransactionRepository.swift`
- Create: `UcapHutangTests/SystemContactsProviderTests.swift`

**Interfaces:**
- Consumes: `ContactRef` (P2), `TransactionRepository` (P2), `InMemoryTransactionRepository` (P2).
- Produces:
  - `enum ContactsAccess: Equatable, Sendable { case notDetermined, authorized, denied }`
  - `protocol ContactsProviding: Sendable { func access() async -> ContactsAccess; func requestAccess() async -> ContactsAccess; func search(name: String) async -> [ContactRef]; func contacts(withIdentifiers ids: [String]) async -> [ContactRef] }`
    - `search` returns `[]` unless authorized; a blank `name` returns all contacts sorted A–Z by given name.
  - `final class SystemContactsProvider: ContactsProviding` with `static func map(_ status: CNAuthorizationStatus) -> ContactsAccess`.
  - `AppContainer.contacts: any ContactsProviding`; `AppContainer.init(repository:extractionService:contacts:storageErrorMessage:)`.
  - Test doubles `FakeContactsProvider` and `SpyTransactionRepository` (APIs shown below).

- [ ] **Step 1: Write the failing mapping test**

Create `UcapHutangTests/SystemContactsProviderTests.swift`:

```swift
import XCTest
import Contacts
@testable import UcapHutang

final class SystemContactsProviderTests: XCTestCase {
    func testOnlyFullAuthorizationCountsAsAuthorized() {
        XCTAssertEqual(SystemContactsProvider.map(.authorized), .authorized)
        XCTAssertEqual(SystemContactsProvider.map(.notDetermined), .notDetermined)
        XCTAssertEqual(SystemContactsProvider.map(.denied), .denied)
        XCTAssertEqual(SystemContactsProvider.map(.restricted), .denied)
        XCTAssertEqual(SystemContactsProvider.map(.limited), .denied)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run the single test class command with `<Class>` = `SystemContactsProviderTests`.

Expected: `error: cannot find 'SystemContactsProvider' in scope`, `** TEST FAILED **`.

- [ ] **Step 3: Implement the boundary and provider**

Replace the entire content of `UcapHutang/Domain/Models/ContactModels.swift` with:

```swift
import Foundation

/// A person picked from the iPhone Contacts app.
struct ContactRef: Hashable, Sendable {
    let identifier: String
    let displayName: String
    let phoneNumber: String?
}

/// Contacts permission as the app treats it. Limited and restricted access count as `.denied`.
enum ContactsAccess: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
}
```

Create `UcapHutang/Domain/Protocols/ContactsProviding.swift`:

```swift
import Foundation

protocol ContactsProviding: Sendable {
    /// Current permission. Async so MainActor-isolated conformers always satisfy the requirement.
    func access() async -> ContactsAccess
    /// Shows the system prompt only when access is not determined; returns the resulting access.
    func requestAccess() async -> ContactsAccess
    /// Contacts whose name matches `name`. A blank `name` returns every contact sorted A–Z.
    /// Returns `[]` unless access is `.authorized`.
    func search(name: String) async -> [ContactRef]
    /// Contacts for the given identifiers, skipping identifiers that no longer exist.
    /// Returns `[]` unless access is `.authorized`.
    func contacts(withIdentifiers ids: [String]) async -> [ContactRef]
}
```

Create `UcapHutang/Services/Contacts/SystemContactsProvider.swift`:

```swift
import Foundation
import Contacts

final class SystemContactsProvider: ContactsProviding {
    private let store = CNContactStore()

    func access() async -> ContactsAccess {
        Self.map(CNContactStore.authorizationStatus(for: .contacts))
    }

    func requestAccess() async -> ContactsAccess {
        let current = await access()
        guard current == .notDetermined else { return current }
        _ = try? await store.requestAccess(for: .contacts)
        return await access()
    }

    func search(name: String) async -> [ContactRef] {
        guard await access() == .authorized else { return [] }
        let request = CNContactFetchRequest(keysToFetch: Self.keysToFetch)
        request.sortOrder = .givenName
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            request.predicate = CNContact.predicateForContacts(matchingName: trimmed)
        }
        return enumerate(request)
    }

    func contacts(withIdentifiers ids: [String]) async -> [ContactRef] {
        guard !ids.isEmpty, await access() == .authorized else { return [] }
        let request = CNContactFetchRequest(keysToFetch: Self.keysToFetch)
        request.sortOrder = .givenName
        request.predicate = CNContact.predicateForContacts(withIdentifiers: ids)
        return enumerate(request)
    }

    static func map(_ status: CNAuthorizationStatus) -> ContactsAccess {
        switch status {
        case .authorized:
            return .authorized
        case .notDetermined:
            return .notDetermined
        case .denied, .restricted, .limited:
            return .denied
        @unknown default:
            return .denied
        }
    }

    private static var keysToFetch: [CNKeyDescriptor] {
        [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]
    }

    private func enumerate(_ request: CNContactFetchRequest) -> [ContactRef] {
        var results: [ContactRef] = []
        try? store.enumerateContacts(with: request) { contact, _ in
            let name = (CNContactFormatter.string(from: contact, style: .fullName) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            results.append(ContactRef(
                identifier: contact.identifier,
                displayName: name,
                phoneNumber: contact.phoneNumbers.first?.value.stringValue
            ))
        }
        return results
    }
}
```

Replace the entire content of `UcapHutang/App/AppContainer.swift` with:

```swift
import Foundation
import Observation
import SwiftData

@Observable
final class AppContainer {
    let repository: any TransactionRepository
    let extractionService: any DraftExtractionService
    let contacts: any ContactsProviding
    let storageErrorMessage: String?

    init(
        repository: any TransactionRepository,
        extractionService: any DraftExtractionService,
        contacts: any ContactsProviding,
        storageErrorMessage: String? = nil
    ) {
        self.repository = repository
        self.extractionService = extractionService
        self.contacts = contacts
        self.storageErrorMessage = storageErrorMessage
    }

    static func makeDefault() -> AppContainer {
        let schema = Schema(versionedSchema: SchemaV2.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let contacts = SystemContactsProvider()
        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: UcapHutangMigrationPlan.self,
                configurations: config
            )
            let repo = SwiftDataTransactionRepository(modelContainer: container)
            let extraction = HybridQwenExtractionService(llmClient: MLXQwenClient())
            return AppContainer(repository: repo, extractionService: extraction, contacts: contacts)
        } catch {
            let fallbackRepo = InMemoryTransactionRepository()
            let extraction = HybridQwenExtractionService(llmClient: MLXQwenClient())
            // SwiftData has no migration-specific error type. If a store file already exists,
            // the failure happened while opening/migrating existing data.
            let storeExists = FileManager.default.fileExists(atPath: config.url.path)
            let message = storeExists
                ? "Migrasi data ke versi terbaru gagal. Demi mencegah kehilangan data, pencatatan dinonaktifkan sementara. Tutup lalu buka kembali aplikasi. Detail: \(error.localizedDescription)"
                : "Penyimpanan lokal tidak dapat dibuka. Demi mencegah kehilangan data, pencatatan dinonaktifkan sementara. Tutup lalu buka kembali aplikasi. Detail: \(error.localizedDescription)"
            return AppContainer(
                repository: fallbackRepo,
                extractionService: extraction,
                contacts: contacts,
                storageErrorMessage: message
            )
        }
    }
}
```

- [ ] **Step 4: Add the test doubles**

Create `UcapHutangTests/TestDoubles/FakeContactsProvider.swift`:

```swift
import Foundation
@testable import UcapHutang

@MainActor
final class FakeContactsProvider: ContactsProviding {
    var currentAccess: ContactsAccess
    var accessAfterRequest: ContactsAccess
    var allContacts: [ContactRef]
    private(set) var requestAccessCallCount = 0

    init(
        access: ContactsAccess = .authorized,
        accessAfterRequest: ContactsAccess = .authorized,
        contacts: [ContactRef] = []
    ) {
        self.currentAccess = access
        self.accessAfterRequest = accessAfterRequest
        self.allContacts = contacts
    }

    func access() async -> ContactsAccess {
        currentAccess
    }

    func requestAccess() async -> ContactsAccess {
        requestAccessCallCount += 1
        if currentAccess == .notDetermined {
            currentAccess = accessAfterRequest
        }
        return currentAccess
    }

    func search(name: String) async -> [ContactRef] {
        guard currentAccess == .authorized else { return [] }
        let sorted = allContacts.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sorted }
        return sorted.filter { $0.displayName.localizedCaseInsensitiveContains(trimmed) }
    }

    func contacts(withIdentifiers ids: [String]) async -> [ContactRef] {
        guard currentAccess == .authorized else { return [] }
        return allContacts.filter { ids.contains($0.identifier) }
    }
}
```

Create `UcapHutangTests/TestDoubles/SpyTransactionRepository.swift`:

```swift
import Foundation
@testable import UcapHutang

/// Wraps an in-memory repository and counts the write calls a ViewModel makes.
/// Seed data through `base` so seeding is not counted.
@MainActor
final class SpyTransactionRepository: TransactionRepository {
    let base: InMemoryTransactionRepository
    private(set) var saveDraftCallCount = 0
    private(set) var confirmDraftCallCount = 0
    private(set) var deleteDraftCallCount = 0

    init(base: InMemoryTransactionRepository = InMemoryTransactionRepository()) {
        self.base = base
    }

    func draftsNeedingReview() async throws -> [TransactionDraft] { try await base.draftsNeedingReview() }
    func pendingDraftCount() async throws -> Int { try await base.pendingDraftCount() }
    func draft(id: UUID) async throws -> TransactionDraft? { try await base.draft(id: id) }

    func saveDraft(_ draft: TransactionDraft) async throws {
        saveDraftCallCount += 1
        try await base.saveDraft(draft)
    }

    func deleteDraft(id: UUID) async throws {
        deleteDraftCallCount += 1
        try await base.deleteDraft(id: id)
    }

    func confirmDraft(_ draft: TransactionDraft) async throws {
        confirmDraftCallCount += 1
        try await base.confirmDraft(draft)
    }

    func ledgerEntries() async throws -> [LedgerEntry] { try await base.ledgerEntries() }
    func linkedContactIdentifiers() async throws -> [String] { try await base.linkedContactIdentifiers() }
    func linkPerson(personID: String, to contact: ContactRef) async throws { try await base.linkPerson(personID: personID, to: contact) }

    func recordPayment(for person: PersonLedgerSummary, amount: Int64, date: Date, notes: String?) async throws {
        try await base.recordPayment(for: person, amount: amount, date: date, notes: notes)
    }
}
```

Note: calls on `base` use `try await` because they go through the actor; the compiler may warn "no calls to throwing functions occur within 'try'" for non-throwing actor methods — leave those warnings.

- [ ] **Step 5: Run to verify it passes**

Run the single test class command with `<Class>` = `SystemContactsProviderTests`. Expected: `Executed 1 test, with 0 failures`.

Run the full test command. Expected: `Executed 58 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add UcapHutang/Domain/Models/ContactModels.swift UcapHutang/Domain/Protocols/ContactsProviding.swift UcapHutang/Services/Contacts/SystemContactsProvider.swift UcapHutang/App/AppContainer.swift UcapHutangTests/TestDoubles/FakeContactsProvider.swift UcapHutangTests/TestDoubles/SpyTransactionRepository.swift UcapHutangTests/SystemContactsProviderTests.swift
git commit -m "feat: add ContactsProviding boundary with system contacts provider"
```

---

### Task 3: Review list shows only real data

**Files:**
- Replace: `UcapHutang/Features/Review/ViewModels/ReviewListViewModel.swift`
- Replace: `UcapHutang/Features/Review/Views/ReviewListView.swift`
- Replace: `UcapHutang/Features/Review/Components/ReviewCardView.swift`
- Create: `UcapHutangTests/ReviewListViewModelTests.swift`

**Interfaces:**
- Consumes: `ReviewItemUIModel`, `ReviewFilterType` (from `ReviewUIModels.swift`, unchanged in this task), `TransactionRepository`.
- Produces:
  - `ReviewListViewModel.init(repository: any TransactionRepository)` (repository no longer optional).
  - `static func ReviewListViewModel.makeItem(from draft: TransactionDraft, now: Date) -> ReviewItemUIModel`.
  - `ReviewListView.init(repository: any TransactionRepository, onSelect: @escaping (UUID) -> Void)`.

- [ ] **Step 1: Write the failing tests**

Create `UcapHutangTests/ReviewListViewModelTests.swift`:

```swift
import XCTest
@testable import UcapHutang

final class ReviewListViewModelTests: XCTestCase {
    func testPersonalDraftWithBlankNameShowsApprovedPlaceholder() {
        let draft = TransactionDraft(
            flow: .personal,
            type: .hutang,
            title: "Bensin",
            totalAmount: 50_000,
            participants: [TransactionParticipant(name: "  ", shareAmount: 50_000)],
            rawTranscript: "pinjam 50 ribu buat bensin"
        )

        let item = ReviewListViewModel.makeItem(from: draft, now: draft.createdAt)

        XCTAssertEqual(item.personName, "Belum ada nama")
        XCTAssertEqual(item.prefix, "dari")
        XCTAssertEqual(item.avatarInitials, [])
    }

    func testSplitDraftUsesRealCountAndInitialsFromRealNamesOnly() {
        let draft = TransactionDraft(
            flow: .splitBill,
            type: .splitBill,
            title: "Makan",
            totalAmount: 90_000,
            splitMethod: .equal,
            participants: [
                TransactionParticipant(name: "satria", shareAmount: 30_000),
                TransactionParticipant(name: "", shareAmount: 30_000)
            ],
            rawTranscript: "makan"
        )

        let item = ReviewListViewModel.makeItem(from: draft, now: draft.createdAt)

        XCTAssertEqual(item.personName, "2 Orang")
        XCTAssertEqual(item.avatarInitials, ["S"])
        XCTAssertEqual(item.prefix, "ke")
    }

    func testSplitDraftWithoutParticipantsShowsZeroAndNoInitials() {
        let draft = TransactionDraft(
            flow: .splitBill,
            type: .splitBill,
            title: "Makan",
            totalAmount: 90_000,
            splitMethod: .equal,
            participants: [],
            rawTranscript: "makan"
        )

        let item = ReviewListViewModel.makeItem(from: draft, now: draft.createdAt)

        XCTAssertEqual(item.personName, "0 Orang")
        XCTAssertEqual(item.avatarInitials, [])
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run the single test class command with `<Class>` = `ReviewListViewModelTests`.

Expected: `error: type 'ReviewListViewModel' has no member 'makeItem'`, `** TEST FAILED **`.

- [ ] **Step 3: Implement**

Replace the entire content of `UcapHutang/Features/Review/ViewModels/ReviewListViewModel.swift` with:

```swift
import Foundation
import Observation

@Observable
final class ReviewListViewModel {
    private(set) var drafts: [ReviewItemUIModel] = []
    var selectedFilter: ReviewFilterType = .all
    var errorMessage: String?

    private let repository: any TransactionRepository

    init(repository: any TransactionRepository) {
        self.repository = repository
    }

    var filteredDrafts: [ReviewItemUIModel] {
        drafts.filter { item in
            switch selectedFilter {
            case .all:
                return true
            case .hutang:
                return item.type == .hutang || item.type == .unknown
            case .piutang:
                return item.type == .piutang
            case .split:
                return item.type == .splitBill
            }
        }
    }

    var isEmpty: Bool {
        filteredDrafts.isEmpty
    }

    func selectFilter(_ filter: ReviewFilterType) {
        selectedFilter = filter
    }

    func loadDrafts() async {
        do {
            let now = Date()
            drafts = try await repository.draftsNeedingReview().map { Self.makeItem(from: $0, now: now) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    static func makeItem(from draft: TransactionDraft, now: Date) -> ReviewItemUIModel {
        let prefix: String
        let personName: String
        var avatarInitials: [String] = []

        if draft.flow == .splitBill || draft.type == .splitBill {
            prefix = "ke"
            personName = "\(draft.participants.count) Orang"
            avatarInitials = draft.participants
                .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(3)
                .map { String($0.prefix(1)).uppercased() }
        } else {
            prefix = draft.type == .piutang ? "ke" : "dari"
            let name = draft.participants.first?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            personName = name.isEmpty ? "Belum ada nama" : name
        }

        let description: String
        if let notes = draft.notes, !notes.isEmpty {
            description = "“\(notes)”"
        } else {
            description = "“\(draft.title)”"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "id_ID")

        return ReviewItemUIModel(
            id: draft.id,
            type: draft.type,
            prefix: prefix,
            personName: personName,
            avatarInitials: avatarInitials,
            description: description,
            relativeTime: formatter.localizedString(for: draft.createdAt, relativeTo: now),
            amount: draft.totalAmount,
            date: draft.transactionDate
        )
    }
}
```

Replace the entire content of `UcapHutang/Features/Review/Views/ReviewListView.swift` with:

```swift
import SwiftUI

struct ReviewListView: View {
    @State private var viewModel: ReviewListViewModel
    let onSelect: (UUID) -> Void

    init(repository: any TransactionRepository, onSelect: @escaping (UUID) -> Void) {
        _viewModel = State(initialValue: ReviewListViewModel(repository: repository))
        self.onSelect = onSelect
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
        ])
    ) { _ in }
}
```

Replace the entire content of `UcapHutang/Features/Review/Components/ReviewCardView.swift` with the P1 version but a new preview. Full content:

```swift
import SwiftUI

struct ReviewCardView: View {
    let item: ReviewItemUIModel

    init(item: ReviewItemUIModel) {
        self.item = item
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Baris 1: Tipe & Waktu Relatif
            HStack {
                Text(typeLabel)
                    .font(.body.weight(.regular))
                    .foregroundStyle(Color.primary)

                Spacer()

                Text(item.relativeTime)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }

            // Baris 2: Subjek & Nominal
            HStack(alignment: .center, spacing: 6) {
                if !item.avatarInitials.isEmpty {
                    stackedAvatarsView
                }

                if !item.prefix.isEmpty {
                    Text(item.prefix)
                        .font(.body)
                        .foregroundStyle(Color.primary)
                }

                Text(item.personName)
                    .font(.body.weight(.bold))
                    .foregroundStyle(Color.primary)

                Spacer()

                Text(item.amount.rupiahFormatted)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.primary)
            }

            // Baris 3: Deskripsi / Quotes
            Text(item.description)
                .font(.body)
                .foregroundStyle(Color.primary)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }

    private var typeLabel: String {
        switch item.type {
        case .piutang:
            return "Piutang"
        case .hutang, .unknown:
            return "Utang"
        case .splitBill:
            return "Split"
        }
    }

    private var stackedAvatarsView: some View {
        HStack(spacing: -6) {
            ForEach(Array(item.avatarInitials.enumerated()), id: \.offset) { index, initial in
                Circle()
                    .fill(Color(.systemGray4))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Text(initial)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color(.systemGray))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 1.5)
                    )
                    .zIndex(Double(item.avatarInitials.count - index))
            }
        }
        .padding(.trailing, 2)
    }
}

#Preview {
    VStack(spacing: 12) {
        ReviewCardView(item: ReviewItemUIModel(
            type: .piutang,
            prefix: "ke",
            personName: "Dito",
            description: "“pinjam buat makan siang”",
            relativeTime: "5 menit yang lalu",
            amount: 15_000
        ))
        ReviewCardView(item: ReviewItemUIModel(
            type: .splitBill,
            prefix: "ke",
            personName: "3 Orang",
            avatarInitials: ["S", "A", "R"],
            description: "“makan malam”",
            relativeTime: "1 jam yang lalu",
            amount: 300_000
        ))
    }
    .padding()
}
```

(The hard-coded font sizes in `ReviewCardView` are fixed in P7, not here.)

- [ ] **Step 4: Run to verify it passes**

Run the single test class command with `<Class>` = `ReviewListViewModelTests`. Expected: `Executed 3 tests, with 0 failures`.

Run the full test command. Expected: `Executed 61 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add UcapHutang/Features/Review/ViewModels/ReviewListViewModel.swift UcapHutang/Features/Review/Views/ReviewListView.swift UcapHutang/Features/Review/Components/ReviewCardView.swift UcapHutangTests/ReviewListViewModelTests.swift
git commit -m "fix: show only real draft data in the Review list"
```

---

### Task 4: Unified Review form, contact picker, wiring, and legacy removal

**Files:**
- Create: `UcapHutangTests/ReviewDetailViewModelTests.swift`
- Create: `UcapHutangTests/ReviewContactPickerViewModelTests.swift`
- Replace: `UcapHutang/Features/Review/Models/ReviewUIModels.swift`
- Replace: `UcapHutang/Features/Review/ViewModels/ReviewDetailViewModel.swift`
- Replace: `UcapHutang/Features/Review/ViewModels/ReviewContactPickerViewModel.swift`
- Replace: `UcapHutang/Features/Review/Components/SmartContactCardView.swift`
- Replace: `UcapHutang/Features/Review/Components/SplitParticipantRow.swift`
- Replace: `UcapHutang/Features/Review/Views/ReviewContactPickerSheet.swift`
- Replace: `UcapHutang/Features/Review/Views/ReviewDetailView.swift`
- Modify: `UcapHutang/App/RootTabView.swift`
- Modify: `UcapHutang/Features/Catat/Views/CatatView.swift`
- Delete: `UcapHutang/Features/Review/Legacy/` (3 files)
- Delete: `UcapHutang/Services/Contacts/ContactResolutionService.swift`

These changes are in one task because the old picker, card, and form types are used by each other; the target only compiles once all of them are replaced.

**Interfaces:**
- Consumes: `ContactsProviding`, `ContactsAccess`, `ContactRef` (Task 2), `TransactionRepository` (P2), `DraftValidator.issues(for:)`, `DraftValidationIssue.message` (P2/Task 1), `SplitCalculationEngine.shares(total:friendCount:includesUser:)`, `.customTotal(_:)` (P2), `FakeContactsProvider`, `SpyTransactionRepository` (Task 2).
- Produces (P4–P6 rely on these):
  - `enum ContactCardState: Equatable, Sendable { case unlinked, suggestion(ContactRef), linked(ContactRef) }`
  - `enum ContactPickerRequest: Identifiable, Hashable, Sendable { case link(participantID: UUID, prefill: String), addParticipants }` with `allowsMultipleSelection: Bool`, `initialQuery: String`.
  - `enum ReviewAlert: Identifiable, Equatable { case incomplete(messages: [String]), contactsAccessRequired, duplicateContact, saveFailed(message: String), deleteFailed(message: String) }` with `title: String`, `message: String?`.
  - `@Observable final class ReviewDetailViewModel` — `init(draftID: UUID, repository: any TransactionRepository, contacts: any ContactsProviding)`; state `loadState`, `draft`, `suggestions`, `hasAttemptedSave`, `isSaving`, `didSave`, `didFinish`, `alert`, `pickerRequest`, `isConfirmingDelete`; derived `issues`, `isDirty`, `isCustomSplit`, `friendsTotal`, `userShare`; methods `load()`, `setTransactionDate(_:)`, `setTotalAmount(_:)`, `setTitle(_:)`, `setType(_:)`, `setSplitMethod(_:)`, `setIncludesUser(_:)`, `setShare(participantID:amount:)`, `removeParticipant(id:)`, `cardState(for:)`, `showsRequiredMarker(for:)`, `requestPicker(_:)`, `confirmSuggestion(participantID:)`, `handlePicked(_:for:)`, `save()`, `delete()`, `persistEditsIfNeeded()`; `static func recalculate(_ draft: inout TransactionDraft)`.
  - `@Observable final class ReviewContactPickerViewModel` — `init(allowsMultipleSelection: Bool, initialQuery: String, contacts: any ContactsProviding, repository: any TransactionRepository)`; `searchQuery`, `recentContacts`, `deviceContacts`, `filteredRecentContacts`, `selectedContacts`, `hasNoResults`, `load()`, `search()`, `toggle(_:)`, `isSelected(_:)`.
  - `struct ReviewDetailView: View` — `init(draftID: UUID, repository: any TransactionRepository, contacts: any ContactsProviding)`. It does **not** create its own `NavigationStack`; presenters provide one.
  - `struct ReviewContactPickerSheet: View` — `init(request: ContactPickerRequest, contacts: any ContactsProviding, repository: any TransactionRepository, onPick: @escaping ([ContactRef]) -> Void)`.

- [ ] **Step 1: Write the failing ViewModel tests**

Create `UcapHutangTests/ReviewDetailViewModelTests.swift`:

```swift
import XCTest
@testable import UcapHutang

@MainActor
final class ReviewDetailViewModelTests: XCTestCase {
    private let satria = ContactRef(identifier: "contact-satria", displayName: "Satria Kans", phoneNumber: nil)

    private func personalDraft(name: String = "Satria", contactIdentifier: String? = nil) -> TransactionDraft {
        TransactionDraft(
            flow: .personal,
            type: .piutang,
            title: "Kopi",
            totalAmount: 20_000,
            participants: [TransactionParticipant(name: name, contactIdentifier: contactIdentifier, shareAmount: 20_000)],
            rawTranscript: "Satria ngutang 20 ribu beli kopi"
        )
    }

    private func splitDraft(friends: [(String, String?)], total: Int64 = 90_000) -> TransactionDraft {
        TransactionDraft(
            flow: .splitBill,
            type: .splitBill,
            title: "Makan malam",
            totalAmount: total,
            splitMethod: .equal,
            participants: friends.map { TransactionParticipant(name: $0.0, contactIdentifier: $0.1, shareAmount: 0) },
            rawTranscript: "makan malam"
        )
    }

    private func makeViewModel(
        seed draft: TransactionDraft?,
        contacts: FakeContactsProvider = FakeContactsProvider()
    ) async throws -> (ReviewDetailViewModel, SpyTransactionRepository) {
        let spy = SpyTransactionRepository()
        if let draft {
            try await spy.base.saveDraft(draft)
        }
        let viewModel = ReviewDetailViewModel(
            draftID: draft?.id ?? UUID(),
            repository: spy,
            contacts: contacts
        )
        await viewModel.load()
        return (viewModel, spy)
    }

    func testLoadShowsTheStoredDraftInsteadOfMockValues() async throws {
        let draft = personalDraft()
        let (viewModel, _) = try await makeViewModel(seed: draft)

        XCTAssertEqual(viewModel.loadState, .loaded)
        XCTAssertEqual(viewModel.draft?.title, "Kopi")
        XCTAssertEqual(viewModel.draft?.totalAmount, 20_000)
        XCTAssertEqual(viewModel.draft?.participants.first?.name, "Satria")
    }

    func testLoadOfMissingDraftShowsNotFound() async throws {
        let (viewModel, _) = try await makeViewModel(seed: nil)
        XCTAssertEqual(viewModel.loadState, .notFound)
    }

    func testSuggestionOnlyForAuthorizedAccessAndExactlyOneMatch() async throws {
        let draft = personalDraft(name: "Satria")

        let oneMatch = FakeContactsProvider(access: .authorized, contacts: [satria])
        let (vmOne, _) = try await makeViewModel(seed: draft, contacts: oneMatch)
        XCTAssertEqual(vmOne.cardState(for: vmOne.draft!.participants[0]), .suggestion(satria))

        let twoMatches = FakeContactsProvider(access: .authorized, contacts: [
            satria,
            ContactRef(identifier: "contact-satria-2", displayName: "Satria Wijaya", phoneNumber: nil)
        ])
        let (vmTwo, _) = try await makeViewModel(seed: draft, contacts: twoMatches)
        XCTAssertEqual(vmTwo.cardState(for: vmTwo.draft!.participants[0]), .unlinked)

        let denied = FakeContactsProvider(access: .denied, contacts: [satria])
        let (vmDenied, _) = try await makeViewModel(seed: draft, contacts: denied)
        XCTAssertEqual(vmDenied.cardState(for: vmDenied.draft!.participants[0]), .unlinked)
    }

    func testRequestingPickerWithDeniedAccessShowsContactsAlert() async throws {
        let draft = personalDraft()
        let (viewModel, _) = try await makeViewModel(seed: draft, contacts: FakeContactsProvider(access: .denied))
        let participantID = viewModel.draft!.participants[0].id

        await viewModel.requestPicker(.link(participantID: participantID, prefill: "Satria"))

        XCTAssertEqual(viewModel.alert, .contactsAccessRequired)
        XCTAssertNil(viewModel.pickerRequest)
    }

    func testRequestingPickerWithUndeterminedAccessAsksThenOpensPicker() async throws {
        let contacts = FakeContactsProvider(access: .notDetermined, accessAfterRequest: .authorized)
        let (viewModel, _) = try await makeViewModel(seed: splitDraft(friends: [("Satria", "contact-satria")]), contacts: contacts)

        await viewModel.requestPicker(.addParticipants)

        XCTAssertEqual(contacts.requestAccessCallCount, 1)
        XCTAssertEqual(viewModel.pickerRequest, .addParticipants)
        XCTAssertNil(viewModel.alert)
    }

    func testSavingWithUnlinkedPersonShowsIssuesAndNeverConfirms() async throws {
        let (viewModel, spy) = try await makeViewModel(seed: personalDraft())
        let participantID = viewModel.draft!.participants[0].id

        await viewModel.save()

        XCTAssertEqual(viewModel.alert, .incomplete(messages: ["Hubungkan setiap orang ke kontak sebelum menyimpan."]))
        XCTAssertEqual(spy.confirmDraftCallCount, 0)
        XCTAssertTrue(viewModel.showsRequiredMarker(for: participantID))
        XCTAssertFalse(viewModel.didFinish)
        let entries = try await spy.ledgerEntries()
        XCTAssertTrue(entries.isEmpty)
    }

    func testSavingLinkedDraftConfirmsAndFinishes() async throws {
        let (viewModel, spy) = try await makeViewModel(seed: personalDraft(contactIdentifier: "contact-satria"))

        await viewModel.save()

        XCTAssertEqual(spy.confirmDraftCallCount, 1)
        XCTAssertTrue(viewModel.didSave)
        XCTAssertTrue(viewModel.didFinish)
        let entries = try await spy.ledgerEntries()
        XCTAssertEqual(entries.count, 1)
    }

    func testLinkingAContactAlreadyUsedByAnotherParticipantShowsDuplicateAlert() async throws {
        let draft = splitDraft(friends: [("Satria Kans", "contact-satria"), ("Ari", nil)])
        let (viewModel, _) = try await makeViewModel(seed: draft)
        let ari = viewModel.draft!.participants[1]

        viewModel.handlePicked([satria], for: .link(participantID: ari.id, prefill: "Ari"))

        XCTAssertEqual(viewModel.alert, .duplicateContact)
        XCTAssertNil(viewModel.draft!.participants[1].contactIdentifier)
        XCTAssertEqual(viewModel.draft!.participants[1].name, "Ari")
    }

    func testEqualSplitRecomputesWhenIncludesUserChanges() async throws {
        let draft = splitDraft(friends: [("Satria", "contact-satria"), ("Ari", "contact-ari")])
        let (viewModel, _) = try await makeViewModel(seed: draft)
        XCTAssertEqual(viewModel.draft!.participants.map(\.shareAmount), [30_000, 30_000])
        XCTAssertEqual(viewModel.userShare, 30_000)

        viewModel.setIncludesUser(false)

        XCTAssertEqual(viewModel.draft!.participants.map(\.shareAmount), [45_000, 45_000])
        XCTAssertEqual(viewModel.userShare, 0)
    }

    func testCustomSplitTotalFollowsTheShares() async throws {
        let draft = splitDraft(friends: [("Satria", "contact-satria"), ("Ari", "contact-ari")])
        let (viewModel, _) = try await makeViewModel(seed: draft)

        viewModel.setSplitMethod(.custom)
        XCTAssertEqual(viewModel.draft!.totalAmount, 60_000)

        viewModel.setShare(participantID: viewModel.draft!.participants[1].id, amount: 40_000)
        XCTAssertEqual(viewModel.draft!.totalAmount, 70_000)

        viewModel.setTotalAmount(1)
        XCTAssertEqual(viewModel.draft!.totalAmount, 70_000, "Nominal is read-only in custom mode")
    }

    func testPersistEditsSavesADirtyDraftWithoutConfirming() async throws {
        let draft = personalDraft()
        let (viewModel, spy) = try await makeViewModel(seed: draft)

        viewModel.setTitle("Kopi susu")
        await viewModel.persistEditsIfNeeded()

        XCTAssertEqual(spy.saveDraftCallCount, 1)
        XCTAssertEqual(spy.confirmDraftCallCount, 0)
        let stored = try await spy.draft(id: draft.id)
        XCTAssertEqual(stored?.title, "Kopi susu")
        XCTAssertEqual(stored?.status, .needsReview)
    }

    func testPersistEditsDoesNothingWhenClean() async throws {
        let (viewModel, spy) = try await makeViewModel(seed: personalDraft())

        await viewModel.persistEditsIfNeeded()

        XCTAssertEqual(spy.saveDraftCallCount, 0)
    }

    func testDeleteRemovesTheDraftAndFinishes() async throws {
        let draft = personalDraft()
        let (viewModel, spy) = try await makeViewModel(seed: draft)

        await viewModel.delete()

        XCTAssertTrue(viewModel.didFinish)
        let stored = try await spy.draft(id: draft.id)
        XCTAssertNil(stored)
    }

    func testRemovingAParticipantRecomputesEqualShares() async throws {
        let draft = splitDraft(friends: [("Satria", "contact-satria"), ("Ari", "contact-ari"), ("Ros", "contact-ros")])
        let (viewModel, _) = try await makeViewModel(seed: draft)
        XCTAssertEqual(viewModel.draft!.participants.map(\.shareAmount), [22_500, 22_500, 22_500])

        viewModel.removeParticipant(id: viewModel.draft!.participants[2].id)

        XCTAssertEqual(viewModel.draft!.participants.map(\.shareAmount), [30_000, 30_000])
    }
}
```

Create `UcapHutangTests/ReviewContactPickerViewModelTests.swift`:

```swift
import XCTest
@testable import UcapHutang

@MainActor
final class ReviewContactPickerViewModelTests: XCTestCase {
    private let ari = ContactRef(identifier: "c-ari", displayName: "Ari", phoneNumber: nil)
    private let budi = ContactRef(identifier: "c-budi", displayName: "Budi", phoneNumber: "+62 811")
    private let citra = ContactRef(identifier: "c-citra", displayName: "Citra", phoneNumber: nil)

    func testLoadShowsContactsThatAlreadyHaveLedgerHistory() async {
        let repository = InMemoryTransactionRepository(seedEntries: [
            LedgerEntry(personID: "c-budi", personName: "Budi", kind: .charge, balanceDelta: 10_000, date: .now, title: "Pulsa", contactIdentifier: "c-budi")
        ])
        let viewModel = ReviewContactPickerViewModel(
            allowsMultipleSelection: false,
            initialQuery: "",
            contacts: FakeContactsProvider(contacts: [citra, ari, budi]),
            repository: repository
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.recentContacts, [budi])
    }

    func testEmptySearchListsAllContactsAlphabetically() async {
        let viewModel = ReviewContactPickerViewModel(
            allowsMultipleSelection: false,
            initialQuery: "",
            contacts: FakeContactsProvider(contacts: [citra, ari, budi]),
            repository: InMemoryTransactionRepository()
        )

        await viewModel.search()

        XCTAssertEqual(viewModel.deviceContacts.map(\.displayName), ["Ari", "Budi", "Citra"])
    }

    func testMultipleSelectionKeepsTapOrderAndToggles() {
        let viewModel = ReviewContactPickerViewModel(
            allowsMultipleSelection: true,
            initialQuery: "",
            contacts: FakeContactsProvider(contacts: [citra, ari, budi]),
            repository: InMemoryTransactionRepository()
        )

        viewModel.toggle(citra)
        viewModel.toggle(ari)
        XCTAssertEqual(viewModel.selectedContacts, [citra, ari])

        viewModel.toggle(citra)
        XCTAssertEqual(viewModel.selectedContacts, [ari])
        XCTAssertFalse(viewModel.isSelected(citra))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run the full test command.

Expected: `error:` lines such as `extra argument 'contacts' in call`, `cannot find 'ContactPickerRequest' in scope`, `value of type 'ReviewDetailViewModel' has no member 'loadState'`; `** TEST FAILED **`.

- [ ] **Step 3: Replace the UI models**

Replace the entire content of `UcapHutang/Features/Review/Models/ReviewUIModels.swift` with:

```swift
import Foundation

// MARK: - Filter Enum
enum ReviewFilterType: String, CaseIterable, Identifiable, Sendable {
    case all = "Semua"
    case hutang = "Utang"
    case piutang = "Piutang"
    case split = "Split"

    var id: String { rawValue }
}

// MARK: - Review Item UI Model
struct ReviewItemUIModel: Identifiable, Equatable, Sendable {
    let id: UUID
    var type: TransactionType
    var prefix: String // "ke" atau "dari"
    var personName: String // "Dito", "Belum ada nama", "3 Orang"
    var avatarInitials: [String]
    var description: String
    var relativeTime: String
    var amount: Int64
    var date: Date

    init(
        id: UUID = UUID(),
        type: TransactionType,
        prefix: String = "",
        personName: String,
        avatarInitials: [String] = [],
        description: String,
        relativeTime: String,
        amount: Int64,
        date: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.prefix = prefix
        self.personName = personName
        self.avatarInitials = avatarInitials
        self.description = description
        self.relativeTime = relativeTime
        self.amount = amount
        self.date = date
    }
}

// MARK: - Contact card state
enum ContactCardState: Equatable, Sendable {
    /// Not linked and no single matching contact.
    case unlinked
    /// Exactly one contact matches the name; the user must confirm.
    case suggestion(ContactRef)
    /// Linked to an iPhone contact.
    case linked(ContactRef)
}

// MARK: - Picker request
enum ContactPickerRequest: Identifiable, Hashable, Sendable {
    case link(participantID: UUID, prefill: String)
    case addParticipants

    var id: String {
        switch self {
        case .link(let participantID, _):
            return "link-\(participantID.uuidString)"
        case .addParticipants:
            return "add-participants"
        }
    }

    var allowsMultipleSelection: Bool {
        if case .addParticipants = self { return true }
        return false
    }

    var initialQuery: String {
        if case .link(_, let prefill) = self { return prefill }
        return ""
    }
}

// MARK: - Alerts
enum ReviewAlert: Identifiable, Equatable {
    case incomplete(messages: [String])
    case contactsAccessRequired
    case duplicateContact
    case saveFailed(message: String)
    case deleteFailed(message: String)

    var id: String {
        switch self {
        case .incomplete: return "incomplete"
        case .contactsAccessRequired: return "contacts-access"
        case .duplicateContact: return "duplicate-contact"
        case .saveFailed: return "save-failed"
        case .deleteFailed: return "delete-failed"
        }
    }

    var title: String {
        switch self {
        case .incomplete: return "Data Belum Lengkap"
        case .contactsAccessRequired: return "Akses Kontak Diperlukan"
        case .duplicateContact: return "Orang ini sudah ada di catatan."
        case .saveFailed: return "Data Belum Bisa Disimpan"
        case .deleteFailed: return "Catatan Belum Bisa Dihapus"
        }
    }

    var message: String? {
        switch self {
        case .incomplete(let messages):
            return messages.map { "• " + $0 }.joined(separator: "\n")
        case .contactsAccessRequired:
            return "UcapHutang perlu akses penuh ke Kontak agar setiap catatan terhubung ke orang yang tepat."
        case .duplicateContact:
            return nil
        case .saveFailed(let message), .deleteFailed(let message):
            return message
        }
    }
}
```

- [ ] **Step 4: Replace `ReviewDetailViewModel.swift`**

Replace the entire content of `UcapHutang/Features/Review/ViewModels/ReviewDetailViewModel.swift` with:

```swift
import Foundation
import Observation

@Observable
final class ReviewDetailViewModel {
    enum LoadState: Equatable {
        case loading
        case loaded
        case notFound
    }

    let draftID: UUID
    private(set) var loadState: LoadState = .loading
    private(set) var draft: TransactionDraft?
    private(set) var suggestions: [UUID: ContactRef] = [:]
    private(set) var hasAttemptedSave = false
    private(set) var isSaving = false
    private(set) var didSave = false
    private(set) var didFinish = false
    var alert: ReviewAlert?
    var pickerRequest: ContactPickerRequest?
    var isConfirmingDelete = false

    @ObservationIgnored private var savedSnapshot: TransactionDraft?
    private let repository: any TransactionRepository
    private let contacts: any ContactsProviding

    init(draftID: UUID, repository: any TransactionRepository, contacts: any ContactsProviding) {
        self.draftID = draftID
        self.repository = repository
        self.contacts = contacts
    }

    // MARK: - Derived state

    var issues: [DraftValidationIssue] {
        guard let draft else { return [] }
        return DraftValidator.issues(for: draft)
    }

    var isDirty: Bool {
        draft != savedSnapshot
    }

    var isCustomSplit: Bool {
        guard let draft, draft.flow == .splitBill else { return false }
        return (draft.splitMethod ?? .equal) == .custom
    }

    var friendsTotal: Int64 {
        SplitCalculationEngine.customTotal(draft?.participants.map(\.shareAmount) ?? []) ?? 0
    }

    var userShare: Int64 {
        guard let draft, draft.flow == .splitBill, !isCustomSplit, draft.includesUser else { return 0 }
        return max(0, draft.totalAmount - friendsTotal)
    }

    func cardState(for participant: TransactionParticipant) -> ContactCardState {
        if Self.isLinked(participant), let identifier = participant.contactIdentifier {
            return .linked(ContactRef(identifier: identifier, displayName: participant.name, phoneNumber: nil))
        }
        if let suggestion = suggestions[participant.id] {
            return .suggestion(suggestion)
        }
        return .unlinked
    }

    func showsRequiredMarker(for participantID: UUID) -> Bool {
        hasAttemptedSave && issues.contains(.participantNotLinked(participantID: participantID))
    }

    // MARK: - Loading

    func load() async {
        do {
            guard var loaded = try await repository.draft(id: draftID) else {
                loadState = .notFound
                return
            }
            Self.recalculate(&loaded)
            draft = loaded
            savedSnapshot = loaded
            loadState = .loaded
            await refreshSuggestions()
        } catch {
            loadState = .notFound
        }
    }

    // MARK: - Field edits

    func setTransactionDate(_ date: Date) {
        mutate { $0.transactionDate = date }
    }

    func setTotalAmount(_ amount: Int64) {
        guard !isCustomSplit else { return }
        mutate { $0.totalAmount = max(0, amount) }
    }

    func setTitle(_ title: String) {
        mutate { $0.title = title }
    }

    func setType(_ type: TransactionType) {
        mutate { $0.type = type }
    }

    func setSplitMethod(_ method: SplitMethod) {
        mutate { $0.splitMethod = method }
    }

    func setIncludesUser(_ includesUser: Bool) {
        mutate { $0.includesUser = includesUser }
    }

    func setShare(participantID: UUID, amount: Int64) {
        mutate { draft in
            guard let index = draft.participants.firstIndex(where: { $0.id == participantID }) else { return }
            draft.participants[index].shareAmount = max(0, amount)
        }
    }

    func removeParticipant(id: UUID) {
        mutate { draft in
            guard draft.flow == .splitBill else { return }
            draft.participants.removeAll { $0.id == id }
        }
        suggestions[id] = nil
    }

    // MARK: - Contacts

    func requestPicker(_ request: ContactPickerRequest) async {
        switch await contacts.access() {
        case .authorized:
            pickerRequest = request
        case .denied:
            alert = .contactsAccessRequired
        case .notDetermined:
            if await contacts.requestAccess() == .authorized {
                pickerRequest = request
                await refreshSuggestions()
            } else {
                alert = .contactsAccessRequired
            }
        }
    }

    func confirmSuggestion(participantID: UUID) {
        guard let contact = suggestions[participantID] else { return }
        link(participantID: participantID, to: contact)
    }

    func handlePicked(_ picked: [ContactRef], for request: ContactPickerRequest) {
        switch request {
        case .link(let participantID, _):
            guard let contact = picked.first else { return }
            link(participantID: participantID, to: contact)
        case .addParticipants:
            addParticipants(picked)
        }
    }

    // MARK: - Save / delete / close

    func save() async {
        guard !isSaving, let current = draft else { return }
        hasAttemptedSave = true
        let currentIssues = DraftValidator.issues(for: current)
        guard currentIssues.isEmpty else {
            alert = .incomplete(messages: Self.distinctMessages(currentIssues))
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await repository.confirmDraft(current)
            savedSnapshot = current
            didSave = true
            didFinish = true
        } catch {
            alert = .saveFailed(message: error.localizedDescription)
        }
    }

    func delete() async {
        do {
            try await repository.deleteDraft(id: draftID)
            didFinish = true
        } catch {
            alert = .deleteFailed(message: error.localizedDescription)
        }
    }

    /// Called when the screen disappears. Writes unsaved edits back to the draft (never to Riwayat).
    func persistEditsIfNeeded() async {
        guard !didFinish, loadState == .loaded, let current = draft, current != savedSnapshot else { return }
        do {
            try await repository.saveDraft(current)
            savedSnapshot = current
        } catch {
            // The screen is already gone; the stored draft keeps its previous values.
        }
    }

    // MARK: - Split math

    static func recalculate(_ draft: inout TransactionDraft) {
        switch draft.flow {
        case .personal:
            for index in draft.participants.indices {
                draft.participants[index].shareAmount = draft.totalAmount
            }
        case .splitBill:
            if (draft.splitMethod ?? .equal) == .custom {
                if let total = SplitCalculationEngine.customTotal(draft.participants.map(\.shareAmount)) {
                    draft.totalAmount = total
                }
            } else {
                let shares = SplitCalculationEngine.shares(
                    total: draft.totalAmount,
                    friendCount: draft.participants.count,
                    includesUser: draft.includesUser
                )
                for (index, share) in shares.enumerated() {
                    draft.participants[index].shareAmount = share
                }
            }
        }
    }

    // MARK: - Private

    private func mutate(_ change: (inout TransactionDraft) -> Void) {
        guard var updated = draft else { return }
        change(&updated)
        Self.recalculate(&updated)
        draft = updated
    }

    private func link(participantID: UUID, to contact: ContactRef) {
        guard let current = draft else { return }
        let usedByAnother = current.participants.contains {
            $0.id != participantID && $0.contactIdentifier == contact.identifier
        }
        guard !usedByAnother else {
            alert = .duplicateContact
            return
        }
        mutate { draft in
            guard let index = draft.participants.firstIndex(where: { $0.id == participantID }) else { return }
            draft.participants[index].name = contact.displayName
            draft.participants[index].contactIdentifier = contact.identifier
        }
        suggestions[participantID] = nil
    }

    private func addParticipants(_ picked: [ContactRef]) {
        guard let current = draft, current.flow == .splitBill else { return }
        var usedIdentifiers = Set(current.participants.compactMap(\.contactIdentifier))
        var additions: [TransactionParticipant] = []
        var foundDuplicate = false
        for contact in picked {
            guard !usedIdentifiers.contains(contact.identifier) else {
                foundDuplicate = true
                continue
            }
            usedIdentifiers.insert(contact.identifier)
            additions.append(TransactionParticipant(
                name: contact.displayName,
                contactIdentifier: contact.identifier,
                shareAmount: 0
            ))
        }
        mutate { $0.participants.append(contentsOf: additions) }
        if foundDuplicate {
            alert = .duplicateContact
        }
    }

    private func refreshSuggestions() async {
        guard let current = draft, await contacts.access() == .authorized else {
            suggestions = [:]
            return
        }
        var result: [UUID: ContactRef] = [:]
        for participant in current.participants where !Self.isLinked(participant) {
            let name = participant.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let matches = await contacts.search(name: name)
            if matches.count == 1 {
                result[participant.id] = matches[0]
            }
        }
        suggestions = result
    }

    private static func isLinked(_ participant: TransactionParticipant) -> Bool {
        let identifier = participant.contactIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !identifier.isEmpty
    }

    private static func distinctMessages(_ issues: [DraftValidationIssue]) -> [String] {
        var seen = Set<String>()
        return issues.map(\.message).filter { seen.insert($0).inserted }
    }
}
```

- [ ] **Step 5: Replace `ReviewContactPickerViewModel.swift`**

Replace the entire content of `UcapHutang/Features/Review/ViewModels/ReviewContactPickerViewModel.swift` with:

```swift
import Foundation
import Observation

@Observable
final class ReviewContactPickerViewModel {
    let allowsMultipleSelection: Bool
    var searchQuery: String
    private(set) var recentContacts: [ContactRef] = []
    private(set) var deviceContacts: [ContactRef] = []
    private(set) var selectedContacts: [ContactRef] = []

    private let contacts: any ContactsProviding
    private let repository: any TransactionRepository

    init(
        allowsMultipleSelection: Bool,
        initialQuery: String,
        contacts: any ContactsProviding,
        repository: any TransactionRepository
    ) {
        self.allowsMultipleSelection = allowsMultipleSelection
        self.searchQuery = initialQuery
        self.contacts = contacts
        self.repository = repository
    }

    var filteredRecentContacts: [ContactRef] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return recentContacts }
        return recentContacts.filter { $0.displayName.localizedCaseInsensitiveContains(query) }
    }

    var hasNoResults: Bool {
        filteredRecentContacts.isEmpty && deviceContacts.isEmpty
    }

    /// Loads contacts that already have Riwayat history.
    func load() async {
        let identifiers = (try? await repository.linkedContactIdentifiers()) ?? []
        recentContacts = await contacts.contacts(withIdentifiers: identifiers)
    }

    /// Refreshes "Kontak di iPhone" for the current query (blank query → all contacts A–Z).
    func search() async {
        deviceContacts = await contacts.search(name: searchQuery)
    }

    func toggle(_ contact: ContactRef) {
        if let index = selectedContacts.firstIndex(of: contact) {
            selectedContacts.remove(at: index)
        } else {
            selectedContacts.append(contact)
        }
    }

    func isSelected(_ contact: ContactRef) -> Bool {
        selectedContacts.contains(contact)
    }
}
```

- [ ] **Step 6: Replace the card and share row components**

Replace the entire content of `UcapHutang/Features/Review/Components/SmartContactCardView.swift` with:

```swift
import SwiftUI

struct SmartContactCardView: View {
    let name: String
    let state: ContactCardState
    let showsRequiredMarker: Bool
    let onLink: () -> Void
    let onConfirmSuggestion: () -> Void
    let onChooseOther: () -> Void
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch state {
            case .unlinked:
                HStack(alignment: .center, spacing: 12) {
                    labels(title: displayName, subtitle: "Belum terhubung")
                    Spacer(minLength: 8)
                    cardButton("Hubungkan", accessibilityLabel: "Hubungkan \(displayName) ke kontak", action: onLink)
                }

            case .suggestion(let contact):
                labels(title: displayName, subtitle: "Mirip kontak “\(contact.displayName)”")
                HStack(spacing: 8) {
                    cardButton("Ya, hubungkan", accessibilityLabel: "Hubungkan ke \(contact.displayName)", action: onConfirmSuggestion)
                    cardButton("Bukan, pilih lain", accessibilityLabel: "Pilih kontak lain untuk \(displayName)", action: onChooseOther)
                }

            case .linked(let contact):
                HStack(alignment: .center, spacing: 12) {
                    labels(title: contact.displayName, subtitle: "Terhubung ke kontak")
                    Spacer(minLength: 8)
                    cardButton("Ganti", accessibilityLabel: "Ganti kontak \(contact.displayName)", action: onChange)
                }
            }

            if showsRequiredMarker {
                Label("Wajib dihubungkan", systemImage: "exclamationmark.circle")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
    }

    private var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Belum ada nama" : trimmed
    }

    private func labels(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func cardButton(_ title: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(.primary)
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview("3 States") {
    VStack(spacing: 16) {
        SmartContactCardView(name: "Dito", state: .unlinked, showsRequiredMarker: true, onLink: {}, onConfirmSuggestion: {}, onChooseOther: {}, onChange: {})
        SmartContactCardView(
            name: "Dito",
            state: .suggestion(ContactRef(identifier: "1", displayName: "Andito Rizkika", phoneNumber: nil)),
            showsRequiredMarker: false,
            onLink: {}, onConfirmSuggestion: {}, onChooseOther: {}, onChange: {}
        )
        SmartContactCardView(
            name: "Andito Rizkika",
            state: .linked(ContactRef(identifier: "1", displayName: "Andito Rizkika", phoneNumber: nil)),
            showsRequiredMarker: false,
            onLink: {}, onConfirmSuggestion: {}, onChooseOther: {}, onChange: {}
        )
    }
    .padding()
}
```

Replace the entire content of `UcapHutang/Features/Review/Components/SplitParticipantRow.swift` with:

```swift
import SwiftUI

/// Shows one friend's share. Editable only in custom split mode.
struct SplitParticipantRow: View {
    let amount: Int64
    let isEditable: Bool
    let onAmountChange: (Int64) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("Nominal bagian")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            if isEditable {
                TextField(
                    "Nominal bagian",
                    value: Binding(get: { amount }, set: { onAmountChange($0) }),
                    format: .number
                )
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.body.weight(.semibold))
                .frame(minHeight: 44)
            } else {
                Text(amount.rupiahFormatted)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
        .accessibilityElement(children: isEditable ? .contain : .combine)
    }
}
```

- [ ] **Step 7: Replace the picker sheet**

Replace the entire content of `UcapHutang/Features/Review/Views/ReviewContactPickerSheet.swift` with:

```swift
import SwiftUI

struct ReviewContactPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ReviewContactPickerViewModel
    private let onPick: ([ContactRef]) -> Void

    init(
        request: ContactPickerRequest,
        contacts: any ContactsProviding,
        repository: any TransactionRepository,
        onPick: @escaping ([ContactRef]) -> Void
    ) {
        _viewModel = State(initialValue: ReviewContactPickerViewModel(
            allowsMultipleSelection: request.allowsMultipleSelection,
            initialQuery: request.initialQuery,
            contacts: contacts,
            repository: repository
        ))
        self.onPick = onPick
    }

    var body: some View {
        NavigationStack {
            List {
                if !viewModel.filteredRecentContacts.isEmpty {
                    Section("Kontak yang pernah dicatat") {
                        ForEach(viewModel.filteredRecentContacts, id: \.identifier) { contact in
                            row(contact)
                        }
                    }
                }
                if !viewModel.deviceContacts.isEmpty {
                    Section("Kontak di iPhone") {
                        ForEach(viewModel.deviceContacts, id: \.identifier) { contact in
                            row(contact)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .overlay {
                if viewModel.hasNoResults {
                    ContentUnavailableView.search(text: viewModel.searchQuery)
                }
            }
            .navigationTitle("Hubungkan ke kontak")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $viewModel.searchQuery,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Cari kontak"
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }
                if viewModel.allowsMultipleSelection {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Selesai") {
                            onPick(viewModel.selectedContacts)
                            dismiss()
                        }
                        .disabled(viewModel.selectedContacts.isEmpty)
                    }
                }
            }
            .task { await viewModel.load() }
            .task(id: viewModel.searchQuery) { await viewModel.search() }
        }
    }

    private func row(_ contact: ContactRef) -> some View {
        Button {
            if viewModel.allowsMultipleSelection {
                viewModel.toggle(contact)
            } else {
                onPick([contact])
                dismiss()
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.displayName)
                        .font(.body)
                        .foregroundStyle(.primary)
                    if let phone = contact.phoneNumber {
                        Text(phone)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                if viewModel.allowsMultipleSelection {
                    Image(systemName: viewModel.isSelected(contact) ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                        .foregroundStyle(viewModel.isSelected(contact) ? Color.accentColor : Color.secondary)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(viewModel.allowsMultipleSelection && viewModel.isSelected(contact) ? .isSelected : [])
    }
}
```

- [ ] **Step 8: Replace `ReviewDetailView.swift`**

Replace the entire content of `UcapHutang/Features/Review/Views/ReviewDetailView.swift` with:

```swift
import SwiftUI

struct ReviewDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var viewModel: ReviewDetailViewModel
    private let repository: any TransactionRepository
    private let contacts: any ContactsProviding

    init(draftID: UUID, repository: any TransactionRepository, contacts: any ContactsProviding) {
        self.repository = repository
        self.contacts = contacts
        _viewModel = State(initialValue: ReviewDetailViewModel(
            draftID: draftID,
            repository: repository,
            contacts: contacts
        ))
    }

    var body: some View {
        content
            .navigationTitle("Review Catatan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }
                }
            }
            .task { await viewModel.load() }
            .onDisappear {
                Task { await viewModel.persistEditsIfNeeded() }
            }
            .onChange(of: viewModel.didFinish) { _, finished in
                if finished { dismiss() }
            }
            .sensoryFeedback(.success, trigger: viewModel.didSave)
            .sheet(item: $viewModel.pickerRequest) { request in
                ReviewContactPickerSheet(request: request, contacts: contacts, repository: repository) { picked in
                    viewModel.handlePicked(picked, for: request)
                }
            }
            .confirmationDialog("Hapus catatan ini?", isPresented: $viewModel.isConfirmingDelete, titleVisibility: .visible) {
                Button("Hapus", role: .destructive) {
                    Task { await viewModel.delete() }
                }
                Button("Batal", role: .cancel) {}
            } message: {
                Text("Catatan dan transkripnya akan dihapus permanen.")
            }
            .alert(
                viewModel.alert?.title ?? "",
                isPresented: Binding(
                    get: { viewModel.alert != nil },
                    set: { if !$0 { viewModel.alert = nil } }
                ),
                presenting: viewModel.alert
            ) { alert in
                switch alert {
                case .incomplete:
                    Button("Periksa Lagi", role: .cancel) {}
                case .contactsAccessRequired:
                    Button("Buka Pengaturan") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    Button("Nanti", role: .cancel) {}
                case .duplicateContact, .saveFailed, .deleteFailed:
                    Button("OK", role: .cancel) {}
                }
            } message: { alert in
                if let message = alert.message {
                    Text(message)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .notFound:
            ContentUnavailableView("Catatan ini tidak ditemukan.", systemImage: "doc.questionmark")
        case .loaded:
            if let draft = viewModel.draft {
                form(draft)
            }
        }
    }

    private func form(_ draft: TransactionDraft) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                field("Waktu") {
                    DatePicker(
                        "Waktu",
                        selection: Binding(
                            get: { viewModel.draft?.transactionDate ?? Date() },
                            set: { viewModel.setTransactionDate($0) }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "id_ID"))
                }

                field("Nominal") {
                    if viewModel.isCustomSplit {
                        Text(draft.totalAmount.rupiahFormatted)
                            .font(.body.weight(.semibold))
                    } else {
                        TextField(
                            "Nominal",
                            value: Binding(
                                get: { viewModel.draft?.totalAmount ?? 0 },
                                set: { viewModel.setTotalAmount($0) }
                            ),
                            format: .number
                        )
                        .keyboardType(.numberPad)
                        .font(.body.weight(.semibold))
                        .frame(minHeight: 44)
                    }
                }

                field("Deskripsi") {
                    TextField(
                        "Deskripsi transaksi",
                        text: Binding(
                            get: { viewModel.draft?.title ?? "" },
                            set: { viewModel.setTitle($0) }
                        )
                    )
                    .font(.body.weight(.semibold))
                    .frame(minHeight: 44)
                }

                if draft.flow == .personal {
                    field("Jenis") {
                        Picker("Jenis", selection: Binding(
                            get: { viewModel.draft?.type ?? .unknown },
                            set: { viewModel.setType($0) }
                        )) {
                            Text("Utang").tag(TransactionType.hutang)
                            Text("Piutang").tag(TransactionType.piutang)
                        }
                        .pickerStyle(.segmented)
                    }
                } else {
                    field("Metode bagi") {
                        Picker("Metode bagi", selection: Binding(
                            get: { viewModel.draft?.splitMethod ?? .equal },
                            set: { viewModel.setSplitMethod($0) }
                        )) {
                            Text("Bagi Rata").tag(SplitMethod.equal)
                            Text("Custom").tag(SplitMethod.custom)
                        }
                        .pickerStyle(.segmented)
                    }
                    if !viewModel.isCustomSplit {
                        Toggle("Saya ikut dihitung", isOn: Binding(
                            get: { viewModel.draft?.includesUser ?? true },
                            set: { viewModel.setIncludesUser($0) }
                        ))
                        .font(.body)
                    }
                }

                peopleSection(draft)

                if draft.flow == .splitBill {
                    splitSummary(draft)
                }

                actions
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func peopleSection(_ draft: TransactionDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Orang")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(draft.participants) { participant in
                if draft.flow == .splitBill {
                    participantBlock(participant, in: draft)
                        .contextMenu {
                            Button("Hapus dari catatan", role: .destructive) {
                                viewModel.removeParticipant(id: participant.id)
                            }
                        }
                        .accessibilityAction(named: "Hapus dari catatan") {
                            viewModel.removeParticipant(id: participant.id)
                        }
                } else {
                    participantBlock(participant, in: draft)
                }
            }

            if draft.flow == .splitBill {
                Button {
                    Task { await viewModel.requestPicker(.addParticipants) }
                } label: {
                    Text("+ Tambah orang")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }
        }
    }

    private func participantBlock(_ participant: TransactionParticipant, in draft: TransactionDraft) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SmartContactCardView(
                name: participant.name,
                state: viewModel.cardState(for: participant),
                showsRequiredMarker: viewModel.showsRequiredMarker(for: participant.id),
                onLink: { openPicker(for: participant) },
                onConfirmSuggestion: { viewModel.confirmSuggestion(participantID: participant.id) },
                onChooseOther: { openPicker(for: participant) },
                onChange: { openPicker(for: participant) }
            )
            if draft.flow == .splitBill {
                SplitParticipantRow(
                    amount: participant.shareAmount,
                    isEditable: viewModel.isCustomSplit,
                    onAmountChange: { viewModel.setShare(participantID: participant.id, amount: $0) }
                )
                .padding(.horizontal, 14)
            }
        }
    }

    private func openPicker(for participant: TransactionParticipant) {
        Task {
            await viewModel.requestPicker(.link(participantID: participant.id, prefill: participant.name))
        }
    }

    private func splitSummary(_ draft: TransactionDraft) -> some View {
        VStack(spacing: 8) {
            summaryRow("Bagian teman", viewModel.friendsTotal)
            if !viewModel.isCustomSplit && draft.includesUser {
                summaryRow("Bagian kamu", viewModel.userShare)
            }
            Divider()
            summaryRow("Total transaksi", draft.totalAmount)
                .font(.body.weight(.semibold))
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
    }

    private func summaryRow(_ label: String, _ amount: Int64) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(amount.rupiahFormatted)
        }
        .font(.body)
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                Task { await viewModel.save() }
            } label: {
                Group {
                    if viewModel.isSaving {
                        ProgressView()
                            .tint(Color(.systemBackground))
                    } else {
                        Text("Simpan Catatan")
                            .font(.headline)
                    }
                }
                .foregroundStyle(Color(.systemBackground))
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.primary)
            .disabled(viewModel.isSaving)

            Button("Hapus catatan ini", role: .destructive) {
                viewModel.isConfirmingDelete = true
            }
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(.top, 12)
    }
}

#if DEBUG
private final class PreviewContactsProvider: ContactsProviding {
    func access() async -> ContactsAccess { .authorized }
    func requestAccess() async -> ContactsAccess { .authorized }
    func search(name: String) async -> [ContactRef] {
        [ContactRef(identifier: "preview-dito", displayName: "Andito Rizkika", phoneNumber: "+62 812")]
    }
    func contacts(withIdentifiers ids: [String]) async -> [ContactRef] { [] }
}

#Preview("Review Personal") {
    let draft = TransactionDraft(
        flow: .personal,
        type: .hutang,
        title: "Pinjam buat makan siang",
        totalAmount: 150_000,
        participants: [TransactionParticipant(name: "Dito", shareAmount: 150_000)],
        rawTranscript: "Pinjam 150 ribu ke Dito buat makan siang"
    )
    return NavigationStack {
        ReviewDetailView(
            draftID: draft.id,
            repository: InMemoryTransactionRepository(seedDrafts: [draft]),
            contacts: PreviewContactsProvider()
        )
    }
}
#endif
```

- [ ] **Step 9: Wire the new Review into the app and remove legacy code**

In `UcapHutang/App/RootTabView.swift`, replace:

```swift
                ReviewDetailView(draftID: item.id, repository: container.repository)
```

with:

```swift
                ReviewDetailView(draftID: item.id, repository: container.repository, contacts: container.contacts)
```

In `UcapHutang/Features/Catat/Views/CatatView.swift`, replace:

```swift
            .navigationDestination(item: $viewModel.createdDraftID) { draftID in
                ReviewDraftView(draftID: draftID, repository: viewModel.container.repository)
            }
```

with:

```swift
            // Temporary until P4 replaces this with "close + banner".
            .navigationDestination(item: $viewModel.createdDraftID) { draftID in
                ReviewDetailView(
                    draftID: draftID,
                    repository: viewModel.container.repository,
                    contacts: viewModel.container.contacts
                )
            }
```

Delete the legacy files:

```bash
git rm UcapHutang/Features/Review/Legacy/ReviewDraftView.swift UcapHutang/Features/Review/Legacy/ReviewDraftViewModel.swift UcapHutang/Features/Review/Legacy/ContactPickerSheet.swift UcapHutang/Services/Contacts/ContactResolutionService.swift
find UcapHutang/Features/Review/Legacy -type d -empty -delete 2>/dev/null; test ! -e UcapHutang/Features/Review/Legacy && echo "Legacy removed"
```

Expected last line: `Legacy removed`.

- [ ] **Step 10: Run the new tests**

Run the single test class command with `<Class>` = `ReviewDetailViewModelTests`. Expected: `Executed 14 tests, with 0 failures`.

Run the single test class command with `<Class>` = `ReviewContactPickerViewModelTests`. Expected: `Executed 3 tests, with 0 failures`.

Run the full test command. Expected: `Executed 78 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 11: Verify removed APIs are gone**

```bash
grep -rn --include='*.swift' -E "ReviewMockData|\bContactUIModel\b|SelectedContactUIModel|ReviewParticipantUIModel|ContactLinkState|ContactResolutionService|ReviewDraftView|ReviewDraftViewModel|\bContactPickerSheet\b|@retroactive|\[safe:|ObservableObject|import Combine|Buat kontak baru" UcapHutang UcapHutangTests
```

Expected: **no output**.

- [ ] **Step 12: Commit**

```bash
git add UcapHutang/Features/Review UcapHutang/App/RootTabView.swift UcapHutang/Features/Catat/Views/CatatView.swift UcapHutangTests/ReviewDetailViewModelTests.swift UcapHutangTests/ReviewContactPickerViewModelTests.swift
git commit -m "feat: unified Review with mandatory contact linking and remove legacy review"
```

---

### Task 5: Manual verification on the simulator (report to the developer)

**Files:** none changed.

The agent cannot create a real voice draft on the simulator (MLX inference needs a device), so this task checks what it can and hands the rest to the developer.

- [ ] **Step 1: Build, install, and grant Contacts access**

```bash
xcodebuild build -project UcapHutang.xcodeproj -scheme UcapHutang -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath build/DerivedData -quiet
xcrun simctl boot "iPhone 17" 2>/dev/null || true
xcrun simctl install "iPhone 17" build/DerivedData/Build/Products/Debug-iphonesimulator/UcapHutang.app
xcrun simctl privacy "iPhone 17" grant contacts AdhiKrisna.UcapHutang
xcrun simctl launch "iPhone 17" AdhiKrisna.UcapHutang
sleep 5
xcrun simctl io "iPhone 17" screenshot build/p3-review-tab.png
```

Expected: no `error:` lines; `build/p3-review-tab.png` exists.

- [ ] **Step 2: Hand the device checklist to the developer**

Send the developer this checklist verbatim and wait for their confirmation before starting P4:

1. Record a Personal note on a device → the Review form opens with the real transcript values (not "Rp150.000 / Pinjam buat makan siang / Dito").
2. With Contacts permission **not yet asked**, tap **Hubungkan** → the system prompt appears. Choose **Don't Allow** → alert "Akses Kontak Diperlukan" with **Buka Pengaturan** / **Nanti**.
3. In iOS Settings, set Contacts to **Limited** for UcapHutang → tapping **Hubungkan** still shows "Akses Kontak Diperlukan".
4. Set Contacts to **Full Access** → a name matching exactly one contact shows "Mirip kontak “…”"; nothing is linked until **Ya, hubungkan**.
5. Tap **Simpan Catatan** with an unlinked person → alert "Data Belum Lengkap" (button **Periksa Lagi**), card shows "Wajib dihubungkan", Riwayat unchanged, draft still in the Review tab.
6. Link the person and save → the sheet closes with a success haptic; Riwayat shows the contact name.
7. Split Bill: toggle "Saya ikut dihitung" and switch Bagi Rata / Custom → shares and "Total transaksi" update; long-press a participant → "Hapus dari catatan" removes them.
8. Edit Deskripsi, then close with **Tutup** without saving → reopen the draft from the Review tab → the edit is still there.
9. "Hapus catatan ini" → confirm → the draft disappears from the Review tab.

## Phase exit checklist

- [ ] `git status --porcelain` shows only `?? .xcede/` and `?? xcede.yml`.
- [ ] `git log --oneline -4` shows the four P3 commits.
- [ ] Full test command: `Executed 78 tests, with 0 failures`, `** TEST SUCCEEDED **`.
- [ ] The developer confirmed the Task 5 checklist.
