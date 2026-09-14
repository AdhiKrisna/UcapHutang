# P0 — Contact-Link Guard Implementation Plan

> **For agentic workers (Gemini 3.7 Flash):** Execute the tasks in order, one step at a time. Steps use checkbox (`- [ ]`) syntax — tick each one as you finish it. Never skip a "run the test and confirm it fails" step. If an actual result differs from the "Expected" text, stop and report instead of improvising.

**Goal:** Make it impossible to confirm a draft into Riwayat (ledger) when any participant is not linked to an iPhone contact, from any code path.

**Architecture:** The rule lives in the domain validator `DraftValidator.validateForConfirmation(_:)`. Both repositories (`InMemoryTransactionRepository`, `SwiftDataTransactionRepository`) already call the validator before writing anything, so enforcing it there closes every UI path. This phase adds regression tests at the validator and repository level and updates two existing tests whose fixtures used unlinked people.

**Tech Stack:** Swift 5 language mode, Xcode 26.6, iOS 26.5 deployment target, SwiftData, XCTest.

**Spec:** `docs/superpowers/specs/2026-09-12-voice-draft-remediation-design.md` (§2, §6.2, §13, §14 P0).

## Global Constraints

- Work on branch `fix/all`. Do not create or switch branches.
- **Never modify, stage, revert, or format `UcapHutang/Core/Utilities/QwenOutputDecoder.swift`.** It has an uncommitted change owned by the developer.
- **Never stage `.xcede/` or `xcede.yml`.** Always `git add` explicit file paths; never `git add -A`, `git add .`, or `git commit -a`.
- Do not edit `UcapHutang.xcodeproj/project.pbxproj`. The app and test targets use file-system-synchronized groups: any `.swift` file created under `UcapHutang/` or `UcapHutangTests/` is compiled automatically.
- Project build settings already in effect: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_VERSION = 5.0`. Do not change them.
- Money is `Int64` Rupiah. Never use `Double` for amounts.
- User-facing strings are Indonesian. The exact new validator message is: `Hubungkan setiap orang ke kontak sebelum menyimpan.`
- Tests use XCTest in the `UcapHutangTests` target with `@testable import UcapHutang`.
- Full test command (baseline on 2026-09-12: 14 tests, all passing):

  ```bash
  xcodebuild test -project UcapHutang.xcodeproj -scheme UcapHutang -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | grep -E "Test Case '.*' (passed|failed)|error:|Executed [0-9]+ tests|TEST SUCCEEDED|TEST FAILED"
  ```

- Single test class command (replace `<Class>`):

  ```bash
  xcodebuild test -project UcapHutang.xcodeproj -scheme UcapHutang -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:UcapHutangTests/<Class> 2>&1 | grep -E "Test Case '.*' (passed|failed)|error:|Executed [0-9]+ tests|TEST SUCCEEDED|TEST FAILED"
  ```

## Known intermediate behavior (accepted by the product owner)

After this phase, the Draft-tab review screen (`UcapHutang/Features/Draft/Views/DraftReviewView.swift`) still uses mock data and never links contacts, so tapping "Simpan Catatan" there will silently fail to save. This is intentional and is fixed in P3. The Catat-path review screen (`UcapHutang/Features/Review/ReviewDraftView.swift`) can still link real contacts and save.

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `UcapHutang/Domain/Models/DraftValidator.swift` | Modify | Add the "every participant linked" rule. |
| `UcapHutangTests/DraftValidatorContactLinkTests.swift` | Create | Validator-level tests for the rule. |
| `UcapHutangTests/ConfirmDraftContactLinkRegressionTests.swift` | Create | Repository-level regression tests (in-memory actor + SwiftData in-memory store). |
| `UcapHutangTests/CoreFlowTests.swift` | Modify | Link the participants in two existing fixtures that confirm drafts. |

---

### Task 1: Validator rejects unlinked participants

**Files:**
- Create: `UcapHutangTests/DraftValidatorContactLinkTests.swift`
- Modify: `UcapHutangTests/CoreFlowTests.swift:33-70`
- Modify: `UcapHutang/Domain/Models/DraftValidator.swift:21-27`

**Interfaces:**
- Consumes (existing, unchanged):
  - `enum DraftValidationError: LocalizedError, Equatable { case invalid(String) }`
  - `enum DraftValidator { static func validateForConfirmation(_ draft: TransactionDraft) throws }`
  - `struct TransactionParticipant { var id: UUID; var name: String; var contactIdentifier: String?; var shareAmount: Int64; var itemTitle: String?; var notes: String? }`
  - `struct TransactionDraft` memberwise init order: `id, status, flow, type, transactionDate, title, totalAmount, splitMethod, participants, notes, rawTranscript, rawModelResponse, reviewWarnings, createdAt` (all fields with defaults may be omitted).
- Produces: `DraftValidator.validateForConfirmation(_:)` throws `DraftValidationError.invalid("Hubungkan setiap orang ke kontak sebelum menyimpan.")` when any participant's `contactIdentifier` is `nil` or only whitespace. Later phases rely on this exact message.

- [ ] **Step 1: Write the failing validator tests**

Create `UcapHutangTests/DraftValidatorContactLinkTests.swift` with exactly this content:

```swift
import XCTest
@testable import UcapHutang

final class DraftValidatorContactLinkTests: XCTestCase {
    private let unlinkedMessage = "Hubungkan setiap orang ke kontak sebelum menyimpan."

    func testPersonalDraftWithUnlinkedPersonIsRejected() {
        let draft = TransactionDraft(
            flow: .personal,
            type: .piutang,
            title: "Kopi",
            totalAmount: 20_000,
            participants: [TransactionParticipant(name: "Satria", shareAmount: 20_000)],
            rawTranscript: "Satria ngutang 20 ribu beli kopi"
        )

        XCTAssertThrowsError(try DraftValidator.validateForConfirmation(draft)) { error in
            XCTAssertEqual(error as? DraftValidationError, .invalid(unlinkedMessage))
        }
    }

    func testSplitBillDraftWithOneUnlinkedParticipantIsRejected() {
        let draft = TransactionDraft(
            flow: .splitBill,
            type: .splitBill,
            title: "Makan malam",
            totalAmount: 90_000,
            splitMethod: .equal,
            participants: [
                TransactionParticipant(name: "Satria", contactIdentifier: "contact-satria", shareAmount: 30_000),
                TransactionParticipant(name: "Ari", shareAmount: 30_000)
            ],
            rawTranscript: "Aku bayarin makan malam 90 ribu sama Satria dan Ari"
        )

        XCTAssertThrowsError(try DraftValidator.validateForConfirmation(draft)) { error in
            XCTAssertEqual(error as? DraftValidationError, .invalid(unlinkedMessage))
        }
    }

    func testBlankContactIdentifierIsTreatedAsUnlinked() {
        let draft = TransactionDraft(
            flow: .personal,
            type: .hutang,
            title: "Bensin",
            totalAmount: 50_000,
            participants: [TransactionParticipant(name: "Dito", contactIdentifier: "   ", shareAmount: 50_000)],
            rawTranscript: "Aku pinjam 50 ribu ke Dito buat bensin"
        )

        XCTAssertThrowsError(try DraftValidator.validateForConfirmation(draft)) { error in
            XCTAssertEqual(error as? DraftValidationError, .invalid(unlinkedMessage))
        }
    }

    func testLinkedPersonalDraftPassesValidation() {
        let draft = TransactionDraft(
            flow: .personal,
            type: .piutang,
            title: "Kopi",
            totalAmount: 20_000,
            participants: [TransactionParticipant(name: "Satria", contactIdentifier: "contact-satria", shareAmount: 20_000)],
            rawTranscript: "Satria ngutang 20 ribu beli kopi"
        )

        XCTAssertNoThrow(try DraftValidator.validateForConfirmation(draft))
    }
}
```

- [ ] **Step 2: Run the new tests to verify they fail**

Run the single test class command with `<Class>` = `DraftValidatorContactLinkTests`.

Expected:
- `testPersonalDraftWithUnlinkedPersonIsRejected` **failed** (no error thrown)
- `testSplitBillDraftWithOneUnlinkedParticipantIsRejected` **failed**
- `testBlankContactIdentifierIsTreatedAsUnlinked` **failed**
- `testLinkedPersonalDraftPassesValidation` **passed**
- Last line: `** TEST FAILED **`

- [ ] **Step 3: Link the participants in existing tests that confirm drafts**

These two existing tests confirm drafts through a repository. Once the rule is implemented they would throw, so give their participants a contact identifier now. In `UcapHutangTests/CoreFlowTests.swift`, replace the two methods `testRepeatedConfirmationCreatesOneLedgerCharge` and `testPaymentUsesLatestBalanceInsteadOfStaleSummary` (currently lines 33–70) with exactly:

```swift
    func testRepeatedConfirmationCreatesOneLedgerCharge() async throws {
        let repository = InMemoryTransactionRepository()
        let draft = TransactionDraft(
            flow: .personal,
            type: .piutang,
            title: "Kopi",
            totalAmount: 20_000,
            participants: [TransactionParticipant(name: "Satria", contactIdentifier: "contact-satria", shareAmount: 20_000)],
            rawTranscript: "Satria ngutang 20 ribu beli kopi"
        )
        try await repository.saveDraft(draft)
        try await repository.confirmDraft(draft)
        try await repository.confirmDraft(draft)
        let entries = await repository.ledgerEntries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.balanceDelta, 20_000)
    }

    func testPaymentUsesLatestBalanceInsteadOfStaleSummary() async throws {
        let repository = InMemoryTransactionRepository()
        let draft = TransactionDraft(
            flow: .personal,
            type: .piutang,
            title: "Kopi",
            totalAmount: 20_000,
            participants: [TransactionParticipant(name: "Satria", contactIdentifier: "contact-satria", shareAmount: 20_000)],
            rawTranscript: "Satria ngutang 20 ribu beli kopi"
        )
        try await repository.saveDraft(draft)
        try await repository.confirmDraft(draft)
        let stale = PersonLedgerSummary(id: "contact-satria", displayName: "Satria", balance: 100_000, entryCount: 1, lastActivity: .now)
        do {
            try await repository.recordPayment(for: stale, amount: 30_000, date: .now, notes: nil)
            XCTFail("Payment above latest balance should fail")
        } catch RepositoryError.paymentExceedsBalance {
            // Expected.
        }
    }
```

Why the summary `id` changed: ledger `personID` is `contactIdentifier ?? name.lowercased()`, so a linked Satria is stored under `"contact-satria"`, not `"satria"`.

- [ ] **Step 4: Run `CoreFlowTests` to verify the updated fixtures still pass before the rule exists**

Run the single test class command with `<Class>` = `CoreFlowTests`.

Expected: `Executed 5 tests, with 0 failures` and `** TEST SUCCEEDED **`.

- [ ] **Step 5: Implement the rule**

In `UcapHutang/Domain/Models/DraftValidator.swift`, find this block:

```swift
        let names = draft.participants.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard names.allSatisfy({ !$0.isEmpty }) else {
            throw DraftValidationError.invalid("Ada nama orang yang masih kosong.")
        }
```

Replace it with:

```swift
        let names = draft.participants.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard names.allSatisfy({ !$0.isEmpty }) else {
            throw DraftValidationError.invalid("Ada nama orang yang masih kosong.")
        }
        let everyParticipantIsLinked = draft.participants.allSatisfy { participant in
            let identifier = participant.contactIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return !identifier.isEmpty
        }
        guard everyParticipantIsLinked else {
            throw DraftValidationError.invalid("Hubungkan setiap orang ke kontak sebelum menyimpan.")
        }
```

Do not change any other rule in the file.

- [ ] **Step 6: Run the validator tests to verify they pass**

Run the single test class command with `<Class>` = `DraftValidatorContactLinkTests`.

Expected: `Executed 4 tests, with 0 failures` and `** TEST SUCCEEDED **`.

- [ ] **Step 7: Run the full suite**

Run the full test command.

Expected: `Executed 18 tests, with 0 failures` and `** TEST SUCCEEDED **` (14 baseline + 4 new).

- [ ] **Step 8: Commit**

```bash
git add UcapHutang/Domain/Models/DraftValidator.swift UcapHutangTests/DraftValidatorContactLinkTests.swift UcapHutangTests/CoreFlowTests.swift
git commit -m "fix: require every participant to be linked to a contact before confirming"
```

---

### Task 2: Repository regression tests (bug reproduction)

**Files:**
- Create: `UcapHutangTests/ConfirmDraftContactLinkRegressionTests.swift`

**Interfaces:**
- Consumes (existing, unchanged):
  - `actor InMemoryTransactionRepository: TransactionRepository` with `init(seedDrafts:seedEntries:)`, `saveDraft(_:)`, `draft(id:) -> TransactionDraft?`, `confirmDraft(_:) throws`, `ledgerEntries() -> [LedgerEntry]`.
  - `@MainActor final class SwiftDataTransactionRepository: TransactionRepository` with `init(modelContainer: ModelContainer)`, `saveDraft(_:) async throws`, `draft(id:) async throws -> TransactionDraft?`, `confirmDraft(_:) async throws`, `ledgerEntries() async throws -> [LedgerEntry]`.
  - SwiftData models `SDTransactionParticipant`, `SDTransactionDraft`, `SDLedgerEntry` (in `UcapHutang/Domain/Models/SwiftDataEntities.swift`).
  - The rule and message from Task 1.
- Produces: nothing new in production code. These tests must keep passing in every later phase (later phases may update type names they reference, never weaken the assertions).

- [ ] **Step 1: Write the regression tests**

Create `UcapHutangTests/ConfirmDraftContactLinkRegressionTests.swift` with exactly this content:

```swift
import XCTest
import SwiftData
@testable import UcapHutang

@MainActor
final class ConfirmDraftContactLinkRegressionTests: XCTestCase {
    private let unlinkedMessage = "Hubungkan setiap orang ke kontak sebelum menyimpan."

    private func makeUnlinkedPersonalDraft() -> TransactionDraft {
        TransactionDraft(
            flow: .personal,
            type: .piutang,
            title: "Kopi",
            totalAmount: 20_000,
            participants: [TransactionParticipant(name: "Satria", shareAmount: 20_000)],
            rawTranscript: "Satria ngutang 20 ribu beli kopi"
        )
    }

    private func makeSwiftDataRepository() throws -> SwiftDataTransactionRepository {
        let schema = Schema([
            SDTransactionParticipant.self,
            SDTransactionDraft.self,
            SDLedgerEntry.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try SwiftData.ModelContainer(for: schema, configurations: configuration)
        return SwiftDataTransactionRepository(modelContainer: container)
    }

    func testInMemoryRepositoryRejectsUnlinkedDraftAndWritesNothing() async throws {
        let repository = InMemoryTransactionRepository()
        let draft = makeUnlinkedPersonalDraft()
        try await repository.saveDraft(draft)

        do {
            try await repository.confirmDraft(draft)
            XCTFail("Confirming a draft with an unlinked person must throw")
        } catch let error as DraftValidationError {
            XCTAssertEqual(error, .invalid(unlinkedMessage))
        }

        let entries = await repository.ledgerEntries()
        XCTAssertTrue(entries.isEmpty, "No ledger entry may be written for an unlinked person")
        let stored = await repository.draft(id: draft.id)
        XCTAssertEqual(stored?.status, .needsReview, "The draft must stay in Draft")
    }

    func testSwiftDataRepositoryRejectsUnlinkedDraftAndWritesNothing() async throws {
        let repository = try makeSwiftDataRepository()
        let draft = makeUnlinkedPersonalDraft()
        try await repository.saveDraft(draft)

        do {
            try await repository.confirmDraft(draft)
            XCTFail("Confirming a draft with an unlinked person must throw")
        } catch let error as DraftValidationError {
            XCTAssertEqual(error, .invalid(unlinkedMessage))
        }

        let entries = try await repository.ledgerEntries()
        XCTAssertTrue(entries.isEmpty, "No ledger entry may be written for an unlinked person")
        let stored = try await repository.draft(id: draft.id)
        XCTAssertEqual(stored?.status, .needsReview, "The draft must stay in Draft")
        let pending = try await repository.draftsNeedingReview()
        XCTAssertEqual(pending.map(\.id), [draft.id])
    }

    func testSwiftDataRepositoryUsesContactIdentifierAsPersonIDForLinkedDraft() async throws {
        let repository = try makeSwiftDataRepository()
        var draft = makeUnlinkedPersonalDraft()
        draft.participants[0].name = "Satria Kans"
        draft.participants[0].contactIdentifier = "contact-satria"
        try await repository.saveDraft(draft)

        try await repository.confirmDraft(draft)

        let entries = try await repository.ledgerEntries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.personID, "contact-satria")
        XCTAssertEqual(entries.first?.personName, "Satria Kans")
        XCTAssertEqual(entries.first?.balanceDelta, 20_000)
        let stored = try await repository.draft(id: draft.id)
        XCTAssertEqual(stored?.status, .confirmed)
    }
}
```

Notes for the implementer:
- `SwiftData.ModelContainer` is written fully qualified on purpose: the app target also links `MLXLMCommon`, which has its own `ModelContainer` type.
- If the compiler warns "no calls to throwing functions occur within 'try' expression" on `InMemoryTransactionRepository.saveDraft`, leave it; the existing `CoreFlowTests` use the same pattern.

- [ ] **Step 2: Run the regression tests**

Run the single test class command with `<Class>` = `ConfirmDraftContactLinkRegressionTests`.

Expected: `Executed 3 tests, with 0 failures` and `** TEST SUCCEEDED **`.

To prove these tests actually guard the bug, do this temporary check and then undo it:

1. In `UcapHutang/Domain/Models/DraftValidator.swift`, temporarily change `guard everyParticipantIsLinked else {` to `guard everyParticipantIsLinked || true else {`.
2. Re-run the same command. Expected: `testInMemoryRepositoryRejectsUnlinkedDraftAndWritesNothing` and `testSwiftDataRepositoryRejectsUnlinkedDraftAndWritesNothing` **failed**, `** TEST FAILED **`.
3. Revert the line back to `guard everyParticipantIsLinked else {`.
4. Run `git diff UcapHutang/Domain/Models/DraftValidator.swift` — expected: **no output** (Task 1's version was already committed, so there must be no diff).

- [ ] **Step 3: Run the full suite**

Run the full test command.

Expected: `Executed 21 tests, with 0 failures` and `** TEST SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add UcapHutangTests/ConfirmDraftContactLinkRegressionTests.swift
git commit -m "test: add regression tests for confirming drafts with unlinked people"
```

---

## Phase exit checklist

- [ ] `git log --oneline -2` shows the two commits from Task 1 and Task 2.
- [ ] `git status --short` shows only ` M UcapHutang/Core/Utilities/QwenOutputDecoder.swift`, `?? .xcede/`, `?? xcede.yml` (pre-existing, untouched).
- [ ] Full test command: `Executed 21 tests, with 0 failures`, `** TEST SUCCEEDED **`.
