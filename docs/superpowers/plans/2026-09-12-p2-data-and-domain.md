# P2 — Domain Rules, SwiftData V2 Migration, and Repository API Implementation Plan

> **For agentic workers (Gemini 3.7 Flash):** Execute the tasks in order, one step at a time. Steps use checkbox (`- [ ]`) syntax — tick each one as you finish it. When a step gives a complete file, replace the **entire** file with it. Never skip a "run the test and confirm it fails" step. If an actual result differs from the "Expected" text, stop and report instead of improvising.

**Goal:** Give the domain one validation rule set that reports every problem, add the fields and repository operations later phases need (permanent delete, pending count, contact linking/merging, payment guard), and version the SwiftData store with a V1 → V2 migration that purges soft-deleted drafts and backfills contact links.

**Architecture:** `DraftValidator.issues(for:)` is the single rule set; `validateForConfirmation` throws the first issue. Split math lives only in `SplitCalculationEngine`. SwiftData models are versioned (`SchemaV1` frozen copy, `SchemaV2` current) with `UcapHutangMigrationPlan`; app code uses typealiases to the V2 models. Both repositories implement the same extended `TransactionRepository` protocol.

**Tech Stack:** Swift 5 language mode, SwiftData (`VersionedSchema`, `SchemaMigrationPlan`, `MigrationStage.custom`), XCTest, Xcode 26.6, iOS 26.5 simulator.

**Spec:** `docs/superpowers/specs/2026-09-12-voice-draft-remediation-design.md` (§6.1–6.6, §12, §14 P2).

## Global Constraints

- Work on branch `fix/all`. **P0 and P1 must be finished** (suite: 21 tests passing; folders as in the P1 plan's "Final file map").
- **Never stage `.xcede/` or `xcede.yml`.** Always `git add` explicit paths (or use `git mv`/`git rm`); never `git add -A`, `git add .`, or `git commit -a`.
- Do not edit `UcapHutang.xcodeproj/project.pbxproj` (file-system-synchronized groups).
- Build settings in effect (do not change): `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_VERSION = 5.0`.
- Money is `Int64` Rupiah.
- `SchemaV1` is a frozen historical copy. Once committed, never edit it.
- In this phase you **may** edit `UcapHutang/Features/Review/Legacy/ReviewDraftViewModel.swift`, but only the single `discardDraft` → `deleteDraft` call described in Task 5.
- Do **not** add the Split Bill share-consistency rules (`sharesDoNotMatchTotal`, equal-share check) to the validator — that is P3.
- Exact user-facing copy (Indonesian) used in this phase:

  | Key | Text |
  |-----|------|
  | `amountNotPositive` | `Isi nominal transaksi dengan angka lebih dari Rp0.` |
  | `titleMissing` | `Isi deskripsi transaksi, misalnya “Kopi” atau “Makan malam”.` |
  | `directionMissing` | `Pilih siapa yang berutang: kamu atau orang tersebut.` |
  | `participantsMissing(.personal)` | `Pilih orang yang terkait dengan transaksi ini.` |
  | `participantsMissing(.splitBill)` | `Tambahkan minimal satu teman yang ikut split bill.` |
  | `participantNameMissing` | `Ada nama orang yang masih kosong.` |
  | `participantNotLinked` | `Hubungkan setiap orang ke kontak sebelum menyimpan.` |
  | `duplicateParticipant` | `Ada orang yang sama dalam satu transaksi. Hapus atau ganti salah satunya.` |
  | `personalRequiresExactlyOne` | `Utang atau piutang pribadi hanya boleh melibatkan satu orang.` |
  | `splitTypeInvalid` | `Jenis transaksi split bill tidak valid.` |
  | `shareNotPositive(name)` | `Isi nominal bagian untuk <name>.` |
  | `sharesExceedTotal` | `Total bagian teman melebihi nominal transaksi.` |
  | `sharesDoNotMatchTotal` | `Pembagian nominal belum sesuai dengan total transaksi.` |
  | `RepositoryError.personNotLinked` | `Hubungkan orang ini ke kontak sebelum mencatat pembayaran.` |
  | `RepositoryError.personNotFound` | `Orang ini tidak ditemukan di Riwayat. Muat ulang Riwayat.` |
  | Migration failure | `Migrasi data ke versi terbaru gagal. Demi mencegah kehilangan data, pencatatan dinonaktifkan sementara. Tutup lalu buka kembali aplikasi. Detail: <error>` |

- Full test command:

  ```bash
  xcodebuild test -project UcapHutang.xcodeproj -scheme UcapHutang -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | grep -E "Test Case '.*' (passed|failed)|error:|Executed [0-9]+ tests|TEST SUCCEEDED|TEST FAILED"
  ```

- Single test class command (replace `<Class>`):

  ```bash
  xcodebuild test -project UcapHutang.xcodeproj -scheme UcapHutang -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:UcapHutangTests/<Class> 2>&1 | grep -E "Test Case '.*' (passed|failed)|error:|Executed [0-9]+ tests|TEST SUCCEEDED|TEST FAILED"
  ```

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `UcapHutang/Core/Utilities/SplitCalculationEngine.swift` | Modify | Add `shares(total:friendCount:includesUser:)` and `customTotal(_:)`. |
| `UcapHutang/Domain/Validation/DraftValidator.swift` | Replace | `DraftValidationIssue`, `issues(for:)`, `validateForConfirmation`. |
| `UcapHutang/Domain/Models/TransactionModels.swift` | Replace | `includesUser`, ledger/summary `contactIdentifier`, remove `DraftStatus.discarded` (Task 5). |
| `UcapHutang/Domain/Models/ContactModels.swift` | Create | `ContactRef`. |
| `UcapHutang/Data/Persistence/SwiftDataEntities.swift` | Delete | Replaced by versioned schemas. |
| `UcapHutang/Data/Persistence/SchemaV1.swift` | Create | Frozen pre-versioning models. |
| `UcapHutang/Data/Persistence/SchemaV2.swift` | Create | Current models. |
| `UcapHutang/Data/Persistence/PersistenceModels.swift` | Create | Typealiases `SD*` → `SchemaV2.SD*`. |
| `UcapHutang/Data/Persistence/UcapHutangMigrationPlan.swift` | Create | V1 → V2 custom stage + data rules. |
| `UcapHutang/App/AppContainer.swift` | Replace | Versioned container + migration failure message. |
| `UcapHutang/Domain/Protocols/TransactionRepository.swift` | Replace | Extended protocol + new errors. |
| `UcapHutang/Data/Persistence/InMemoryTransactionRepository.swift` | Replace | Implements extended protocol. |
| `UcapHutang/Data/Persistence/SwiftDataTransactionRepository.swift` | Replace | Implements extended protocol. |
| `UcapHutang/Features/Review/ViewModels/ReviewListViewModel.swift` | Modify | `discardDraft` → `deleteDraft`. |
| `UcapHutang/Features/Review/ViewModels/ReviewDetailViewModel.swift` | Modify | `discardDraft` → `deleteDraft`. |
| `UcapHutang/Features/Review/Legacy/ReviewDraftViewModel.swift` | Modify (one line) | `discardDraft` → `deleteDraft`. |
| `UcapHutang/Features/Riwayat/ViewModels/LedgerListViewModel.swift` | Modify | Summaries carry `contactIdentifier`. |
| `UcapHutang/Features/Riwayat/ViewModels/PersonLedgerDetailViewModel.swift` | Modify | Reloaded summary carries `contactIdentifier`. |
| `UcapHutangTests/SplitSharesTests.swift` | Create | Split helper tests. |
| `UcapHutangTests/DraftValidatorIssuesTests.swift` | Create | Validator issue tests. |
| `UcapHutangTests/DomainModelDefaultsTests.swift` | Create | New field defaults. |
| `UcapHutangTests/SchemaMigrationV2Tests.swift` | Create | On-disk V1 → V2 migration test. |
| `UcapHutangTests/RepositoryLinkAndDeleteTests.swift` | Create | New repository behavior on both repositories. |

Expected test totals: start 21 → Task 1: 27 → Task 2: 42 → Task 3: 43 → Task 4: 44 → Task 5: 53.

---

### Task 1: Split helpers

**Files:**
- Modify: `UcapHutang/Core/Utilities/SplitCalculationEngine.swift`
- Create: `UcapHutangTests/SplitSharesTests.swift`

**Interfaces:**
- Consumes: `SplitCalculationEngine.calculateEqualShares(totalAmount:participantCount:) -> [Int64]` (existing; remainder goes to the first shares).
- Produces:
  - `SplitCalculationEngine.shares(total: Int64, friendCount: Int, includesUser: Bool) -> [Int64]` — one share per friend, in order.
  - `SplitCalculationEngine.customTotal(_ shares: [Int64]) -> Int64?` — `nil` on overflow.

- [ ] **Step 1: Write the failing tests**

Create `UcapHutangTests/SplitSharesTests.swift`:

```swift
import XCTest
@testable import UcapHutang

final class SplitSharesTests: XCTestCase {
    func testEqualSharesIncludingUserReturnsOnlyFriendsShares() {
        XCTAssertEqual(
            SplitCalculationEngine.shares(total: 100_000, friendCount: 2, includesUser: true),
            [33_334, 33_333]
        )
    }

    func testEqualSharesExcludingUserSplitsAmongFriendsOnly() {
        XCTAssertEqual(
            SplitCalculationEngine.shares(total: 90_000, friendCount: 2, includesUser: false),
            [45_000, 45_000]
        )
    }

    func testRemainderGoesToFirstFriendsWhenUserExcluded() {
        XCTAssertEqual(
            SplitCalculationEngine.shares(total: 100_000, friendCount: 3, includesUser: false),
            [33_334, 33_333, 33_333]
        )
    }

    func testZeroFriendsReturnsNoShares() {
        XCTAssertEqual(SplitCalculationEngine.shares(total: 50_000, friendCount: 0, includesUser: true), [])
    }

    func testCustomTotalSumsShares() {
        XCTAssertEqual(SplitCalculationEngine.customTotal([10_000, 25_000]), 35_000)
    }

    func testCustomTotalReturnsNilOnOverflow() {
        XCTAssertNil(SplitCalculationEngine.customTotal([Int64.max, 1]))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run the single test class command with `<Class>` = `SplitSharesTests`.

Expected: `error:` lines saying `type 'SplitCalculationEngine' has no member 'shares'` (and `customTotal`), then `** TEST FAILED **`.

- [ ] **Step 3: Implement**

In `UcapHutang/Core/Utilities/SplitCalculationEngine.swift`, insert these two methods directly **after** the closing brace of `calculateEqualShares(totalAmount:participantCount:)` (inside the enum):

```swift

    /// Equal split for a user-paid bill. Returns one share per friend, in list order.
    /// When `includesUser` is true the user also takes a share (total ÷ (friends + 1)); that share is not returned.
    /// The integer Rupiah remainder goes to the first shares, so friends absorb it before the user.
    public static func shares(total: Int64, friendCount: Int, includesUser: Bool) -> [Int64] {
        guard friendCount > 0 else { return [] }
        let headCount = friendCount + (includesUser ? 1 : 0)
        return Array(calculateEqualShares(totalAmount: total, participantCount: headCount).prefix(friendCount))
    }

    /// Sum of custom shares, or `nil` when the sum overflows `Int64`.
    public static func customTotal(_ shares: [Int64]) -> Int64? {
        var total: Int64 = 0
        for share in shares {
            let (next, overflow) = total.addingReportingOverflow(share)
            if overflow { return nil }
            total = next
        }
        return total
    }
```

- [ ] **Step 4: Run to verify it passes**

Run the single test class command with `<Class>` = `SplitSharesTests`. Expected: `Executed 6 tests, with 0 failures`.

Run the full test command. Expected: `Executed 27 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add UcapHutang/Core/Utilities/SplitCalculationEngine.swift UcapHutangTests/SplitSharesTests.swift
git commit -m "feat: add friend-share and custom-total split helpers"
```

---

### Task 2: `DraftValidationIssue` and `issues(for:)`

**Files:**
- Replace: `UcapHutang/Domain/Validation/DraftValidator.swift`
- Create: `UcapHutangTests/DraftValidatorIssuesTests.swift`

**Interfaces:**
- Consumes: `SplitCalculationEngine.customTotal(_:)` (Task 1); `TransactionDraft`, `TransactionParticipant`, `CaptureFlow`, `TransactionType`.
- Produces (P3 uses these exact names):
  - `enum DraftValidationIssue: Equatable, Sendable` with cases `amountNotPositive`, `titleMissing`, `directionMissing`, `participantsMissing(flow: CaptureFlow)`, `participantNameMissing(participantID: UUID)`, `participantNotLinked(participantID: UUID)`, `duplicateParticipant`, `personalRequiresExactlyOne`, `splitTypeInvalid`, `shareNotPositive(participantID: UUID, name: String)`, `sharesExceedTotal`, `sharesDoNotMatchTotal`; property `message: String`.
  - `DraftValidator.issues(for draft: TransactionDraft) -> [DraftValidationIssue]`.
  - `DraftValidator.validateForConfirmation(_:) throws` — throws `DraftValidationError.invalid(firstIssue.message)`.
  - `enum DraftValidationError: LocalizedError, Equatable { case invalid(String) }` (unchanged).

- [ ] **Step 1: Write the failing tests**

Create `UcapHutangTests/DraftValidatorIssuesTests.swift`:

```swift
import XCTest
@testable import UcapHutang

final class DraftValidatorIssuesTests: XCTestCase {
    private func linkedPersonalDraft() -> TransactionDraft {
        TransactionDraft(
            flow: .personal,
            type: .piutang,
            title: "Kopi",
            totalAmount: 20_000,
            participants: [TransactionParticipant(name: "Satria", contactIdentifier: "contact-satria", shareAmount: 20_000)],
            rawTranscript: "Satria ngutang 20 ribu beli kopi"
        )
    }

    private func linkedSplitDraft() -> TransactionDraft {
        TransactionDraft(
            flow: .splitBill,
            type: .splitBill,
            title: "Makan malam",
            totalAmount: 90_000,
            splitMethod: .equal,
            participants: [
                TransactionParticipant(name: "Satria", contactIdentifier: "contact-satria", shareAmount: 30_000),
                TransactionParticipant(name: "Ari", contactIdentifier: "contact-ari", shareAmount: 30_000)
            ],
            rawTranscript: "Aku bayarin makan malam 90 ribu sama Satria dan Ari"
        )
    }

    func testValidPersonalDraftHasNoIssues() {
        let draft = linkedPersonalDraft()
        XCTAssertEqual(DraftValidator.issues(for: draft), [])
        XCTAssertNoThrow(try DraftValidator.validateForConfirmation(draft))
    }

    func testValidSplitDraftHasNoIssues() {
        let draft = linkedSplitDraft()
        XCTAssertEqual(DraftValidator.issues(for: draft), [])
        XCTAssertNoThrow(try DraftValidator.validateForConfirmation(draft))
    }

    func testAmountNotPositive() {
        var draft = linkedPersonalDraft()
        draft.totalAmount = 0
        XCTAssertEqual(DraftValidator.issues(for: draft), [.amountNotPositive])
        XCTAssertEqual(DraftValidationIssue.amountNotPositive.message, "Isi nominal transaksi dengan angka lebih dari Rp0.")
    }

    func testTitleMissing() {
        var draft = linkedPersonalDraft()
        draft.title = "   "
        XCTAssertEqual(DraftValidator.issues(for: draft), [.titleMissing])
        XCTAssertEqual(DraftValidationIssue.titleMissing.message, "Isi deskripsi transaksi, misalnya “Kopi” atau “Makan malam”.")
    }

    func testDirectionMissingForPersonal() {
        var draft = linkedPersonalDraft()
        draft.type = .unknown
        XCTAssertEqual(DraftValidator.issues(for: draft), [.directionMissing])
        XCTAssertEqual(DraftValidationIssue.directionMissing.message, "Pilih siapa yang berutang: kamu atau orang tersebut.")
    }

    func testParticipantsMissingUsesFlowSpecificMessage() {
        var personal = linkedPersonalDraft()
        personal.participants = []
        XCTAssertEqual(DraftValidator.issues(for: personal), [.participantsMissing(flow: .personal)])
        XCTAssertEqual(DraftValidationIssue.participantsMissing(flow: .personal).message, "Pilih orang yang terkait dengan transaksi ini.")

        var split = linkedSplitDraft()
        split.participants = []
        XCTAssertEqual(DraftValidator.issues(for: split), [.participantsMissing(flow: .splitBill)])
        XCTAssertEqual(DraftValidationIssue.participantsMissing(flow: .splitBill).message, "Tambahkan minimal satu teman yang ikut split bill.")
    }

    func testParticipantNameMissing() {
        var draft = linkedPersonalDraft()
        draft.participants[0].name = "  "
        let id = draft.participants[0].id
        XCTAssertEqual(DraftValidator.issues(for: draft), [.participantNameMissing(participantID: id)])
        XCTAssertEqual(DraftValidationIssue.participantNameMissing(participantID: id).message, "Ada nama orang yang masih kosong.")
    }

    func testEveryUnlinkedParticipantIsReported() {
        var draft = linkedSplitDraft()
        draft.participants[0].contactIdentifier = nil
        draft.participants[1].contactIdentifier = nil
        XCTAssertEqual(
            DraftValidator.issues(for: draft),
            [
                .participantNotLinked(participantID: draft.participants[0].id),
                .participantNotLinked(participantID: draft.participants[1].id)
            ]
        )
        XCTAssertEqual(
            DraftValidationIssue.participantNotLinked(participantID: draft.participants[0].id).message,
            "Hubungkan setiap orang ke kontak sebelum menyimpan."
        )
    }

    func testDuplicateDetectionUsesContactIdentifier() {
        var draft = linkedSplitDraft()
        draft.participants[1].name = "Satria K"
        draft.participants[1].contactIdentifier = "contact-satria"
        XCTAssertEqual(DraftValidator.issues(for: draft), [.duplicateParticipant])
        XCTAssertEqual(DraftValidationIssue.duplicateParticipant.message, "Ada orang yang sama dalam satu transaksi. Hapus atau ganti salah satunya.")
    }

    func testPersonalRequiresExactlyOnePerson() {
        var draft = linkedPersonalDraft()
        draft.participants.append(TransactionParticipant(name: "Ari", contactIdentifier: "contact-ari", shareAmount: 0))
        XCTAssertEqual(DraftValidator.issues(for: draft), [.personalRequiresExactlyOne])
        XCTAssertEqual(DraftValidationIssue.personalRequiresExactlyOne.message, "Utang atau piutang pribadi hanya boleh melibatkan satu orang.")
    }

    func testSplitTypeInvalid() {
        var draft = linkedSplitDraft()
        draft.type = .piutang
        XCTAssertEqual(DraftValidator.issues(for: draft), [.splitTypeInvalid])
        XCTAssertEqual(DraftValidationIssue.splitTypeInvalid.message, "Jenis transaksi split bill tidak valid.")
    }

    func testShareNotPositiveNamesTheParticipant() {
        var draft = linkedSplitDraft()
        draft.participants[1].shareAmount = 0
        let id = draft.participants[1].id
        XCTAssertEqual(DraftValidator.issues(for: draft), [.shareNotPositive(participantID: id, name: "Ari")])
        XCTAssertEqual(DraftValidationIssue.shareNotPositive(participantID: id, name: "Ari").message, "Isi nominal bagian untuk Ari.")
    }

    func testSharesExceedTotal() {
        var draft = linkedSplitDraft()
        draft.participants[0].shareAmount = 60_000
        draft.participants[1].shareAmount = 60_000
        XCTAssertEqual(DraftValidator.issues(for: draft), [.sharesExceedTotal])
        XCTAssertEqual(DraftValidationIssue.sharesExceedTotal.message, "Total bagian teman melebihi nominal transaksi.")
    }

    func testValidateForConfirmationThrowsTheFirstIssue() {
        var draft = linkedPersonalDraft()
        draft.totalAmount = 0
        draft.participants[0].contactIdentifier = nil
        XCTAssertThrowsError(try DraftValidator.validateForConfirmation(draft)) { error in
            XCTAssertEqual(error as? DraftValidationError, .invalid("Isi nominal transaksi dengan angka lebih dari Rp0."))
        }
    }

    func testSharesDoNotMatchTotalMessage() {
        XCTAssertEqual(DraftValidationIssue.sharesDoNotMatchTotal.message, "Pembagian nominal belum sesuai dengan total transaksi.")
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run the single test class command with `<Class>` = `DraftValidatorIssuesTests`.

Expected: `error:` lines such as `cannot find 'DraftValidationIssue' in scope` and `type 'DraftValidator' has no member 'issues'`, then `** TEST FAILED **`.

- [ ] **Step 3: Implement**

Replace the entire content of `UcapHutang/Domain/Validation/DraftValidator.swift` with:

```swift
import Foundation

enum DraftValidationError: LocalizedError, Equatable {
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .invalid(let message): message
        }
    }
}

enum DraftValidationIssue: Equatable, Sendable {
    case amountNotPositive
    case titleMissing
    case directionMissing
    case participantsMissing(flow: CaptureFlow)
    case participantNameMissing(participantID: UUID)
    case participantNotLinked(participantID: UUID)
    case duplicateParticipant
    case personalRequiresExactlyOne
    case splitTypeInvalid
    case shareNotPositive(participantID: UUID, name: String)
    case sharesExceedTotal
    case sharesDoNotMatchTotal

    var message: String {
        switch self {
        case .amountNotPositive:
            "Isi nominal transaksi dengan angka lebih dari Rp0."
        case .titleMissing:
            "Isi deskripsi transaksi, misalnya “Kopi” atau “Makan malam”."
        case .directionMissing:
            "Pilih siapa yang berutang: kamu atau orang tersebut."
        case .participantsMissing(let flow):
            flow == .personal
                ? "Pilih orang yang terkait dengan transaksi ini."
                : "Tambahkan minimal satu teman yang ikut split bill."
        case .participantNameMissing:
            "Ada nama orang yang masih kosong."
        case .participantNotLinked:
            "Hubungkan setiap orang ke kontak sebelum menyimpan."
        case .duplicateParticipant:
            "Ada orang yang sama dalam satu transaksi. Hapus atau ganti salah satunya."
        case .personalRequiresExactlyOne:
            "Utang atau piutang pribadi hanya boleh melibatkan satu orang."
        case .splitTypeInvalid:
            "Jenis transaksi split bill tidak valid."
        case .shareNotPositive(_, let name):
            "Isi nominal bagian untuk \(name)."
        case .sharesExceedTotal:
            "Total bagian teman melebihi nominal transaksi."
        case .sharesDoNotMatchTotal:
            "Pembagian nominal belum sesuai dengan total transaksi."
        }
    }
}

enum DraftValidator {
    /// Throws the first issue so repositories can refuse to write invalid drafts.
    static func validateForConfirmation(_ draft: TransactionDraft) throws {
        if let firstIssue = issues(for: draft).first {
            throw DraftValidationError.invalid(firstIssue.message)
        }
    }

    /// Every problem that blocks confirmation, in display order.
    static func issues(for draft: TransactionDraft) -> [DraftValidationIssue] {
        var issues: [DraftValidationIssue] = []

        if draft.totalAmount <= 0 {
            issues.append(.amountNotPositive)
        }
        if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.titleMissing)
        }
        if draft.participants.isEmpty {
            issues.append(.participantsMissing(flow: draft.flow))
        }
        for participant in draft.participants
        where participant.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.participantNameMissing(participantID: participant.id))
        }
        for participant in draft.participants where !isLinked(participant) {
            issues.append(.participantNotLinked(participantID: participant.id))
        }
        let identities = draft.participants.map(identityKey).filter { $0 != "name:" }
        if Set(identities).count != identities.count {
            issues.append(.duplicateParticipant)
        }

        switch draft.flow {
        case .personal:
            if draft.type != .hutang && draft.type != .piutang {
                issues.append(.directionMissing)
            }
            if draft.participants.count > 1 {
                issues.append(.personalRequiresExactlyOne)
            }
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

        return issues
    }

    private static func isLinked(_ participant: TransactionParticipant) -> Bool {
        let identifier = participant.contactIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !identifier.isEmpty
    }

    private static func identityKey(_ participant: TransactionParticipant) -> String {
        if isLinked(participant), let identifier = participant.contactIdentifier {
            return "contact:" + identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "name:" + participant.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run the single test class command with `<Class>` = `DraftValidatorIssuesTests`. Expected: `Executed 15 tests, with 0 failures`.

Run the full test command. Expected: `Executed 42 tests, with 0 failures`, `** TEST SUCCEEDED **` (the P0 tests `DraftValidatorContactLinkTests` and `ConfirmDraftContactLinkRegressionTests` must still pass unchanged).

- [ ] **Step 5: Commit**

```bash
git add UcapHutang/Domain/Validation/DraftValidator.swift UcapHutangTests/DraftValidatorIssuesTests.swift
git commit -m "feat: report every draft validation issue with approved messages"
```

---

### Task 3: Domain model fields and `ContactRef`

**Files:**
- Replace: `UcapHutang/Domain/Models/TransactionModels.swift`
- Create: `UcapHutang/Domain/Models/ContactModels.swift`
- Create: `UcapHutangTests/DomainModelDefaultsTests.swift`

**Interfaces:**
- Produces:
  - `TransactionDraft.includesUser: Bool` (default `true`, declared right after `splitMethod`).
  - `LedgerEntry.contactIdentifier: String?` (default `nil`, declared last).
  - `PersonLedgerSummary.contactIdentifier: String?` (default `nil`, declared last) and computed `isLinked: Bool`.
  - `struct ContactRef: Hashable, Sendable { let identifier: String; let displayName: String; let phoneNumber: String? }` with memberwise init `ContactRef(identifier:displayName:phoneNumber:)`.
  - `DraftStatus` still has `discarded` until Task 5.

- [ ] **Step 1: Write the failing test**

Create `UcapHutangTests/DomainModelDefaultsTests.swift`:

```swift
import XCTest
@testable import UcapHutang

final class DomainModelDefaultsTests: XCTestCase {
    func testNewFieldsHaveSafeDefaults() {
        let draft = TransactionDraft(
            flow: .splitBill,
            type: .splitBill,
            title: "Makan",
            totalAmount: 90_000,
            splitMethod: .equal,
            participants: [],
            rawTranscript: "makan"
        )
        XCTAssertTrue(draft.includesUser)

        let entry = LedgerEntry(personID: "budi", personName: "Budi", kind: .charge, balanceDelta: 10_000, date: .now, title: "Pulsa")
        XCTAssertNil(entry.contactIdentifier)

        let unlinked = PersonLedgerSummary(id: "budi", displayName: "Budi", balance: 10_000, entryCount: 1, lastActivity: .now)
        XCTAssertFalse(unlinked.isLinked)
        let linked = PersonLedgerSummary(id: "contact-budi", displayName: "Budi", balance: 10_000, entryCount: 1, lastActivity: .now, contactIdentifier: "contact-budi")
        XCTAssertTrue(linked.isLinked)

        let contact = ContactRef(identifier: "contact-budi", displayName: "Budi Santoso", phoneNumber: nil)
        XCTAssertEqual(contact.displayName, "Budi Santoso")
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run the single test class command with `<Class>` = `DomainModelDefaultsTests`.

Expected: `error:` lines such as `value of type 'TransactionDraft' has no member 'includesUser'` and `cannot find 'ContactRef' in scope`, then `** TEST FAILED **`.

- [ ] **Step 3: Implement**

Replace the entire content of `UcapHutang/Domain/Models/TransactionModels.swift` with:

```swift
import Foundation

enum CaptureFlow: String, Codable, CaseIterable, Identifiable, Sendable {
    case personal
    case splitBill

    var id: String { rawValue }

    var title: String {
        switch self {
        case .personal: "Utang / Piutang"
        case .splitBill: "Split Bill"
        }
    }
}

enum TransactionType: String, Codable, CaseIterable, Sendable {
    case unknown
    case hutang
    case piutang
    case splitBill

    var title: String {
        switch self {
        case .unknown: "Belum Ditentukan"
        case .hutang: "Utang"
        case .piutang: "Piutang"
        case .splitBill: "Split Bill"
        }
    }
}

enum DraftStatus: String, Codable, Sendable {
    case needsReview
    case confirmed
    case discarded
}

enum SplitMethod: String, Codable, CaseIterable, Sendable {
    case equal
    case custom

    var title: String { self == .equal ? "Bagi Rata" : "Nominal Custom" }
}

struct TransactionParticipant: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var name: String
    var contactIdentifier: String?
    var shareAmount: Int64
    var itemTitle: String?
    var notes: String?
}

struct TransactionDraft: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var status: DraftStatus = .needsReview
    var flow: CaptureFlow
    var type: TransactionType
    var transactionDate: Date = Date()
    var title: String
    var totalAmount: Int64
    var splitMethod: SplitMethod?
    /// Split Bill + equal method only: whether the user also takes a share.
    var includesUser: Bool = true
    var participants: [TransactionParticipant]
    var notes: String?
    var rawTranscript: String
    var rawModelResponse: String?
    var reviewWarnings: [String] = []
    var createdAt: Date = Date()
}

enum LedgerEntryKind: String, Codable, Sendable {
    case charge
    case payment
}

struct LedgerEntry: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var personID: String
    var personName: String
    var kind: LedgerEntryKind
    var balanceDelta: Int64
    var date: Date
    var title: String
    var notes: String?
    var sourceDraftID: UUID?
    /// `nil` for legacy people that were saved before contact linking became mandatory.
    var contactIdentifier: String?
}

struct PersonLedgerSummary: Identifiable, Hashable, Sendable {
    var id: String
    var displayName: String
    var balance: Int64
    var entryCount: Int
    var lastActivity: Date
    var contactIdentifier: String?

    var isLinked: Bool { contactIdentifier != nil }
}
```

Create `UcapHutang/Domain/Models/ContactModels.swift`:

```swift
import Foundation

/// A person picked from the iPhone Contacts app.
struct ContactRef: Hashable, Sendable {
    let identifier: String
    let displayName: String
    let phoneNumber: String?
}
```

- [ ] **Step 4: Run to verify it passes**

Run the full test command. Expected: `Executed 43 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add UcapHutang/Domain/Models/TransactionModels.swift UcapHutang/Domain/Models/ContactModels.swift UcapHutangTests/DomainModelDefaultsTests.swift
git commit -m "feat: add includesUser, ledger contact identifier and ContactRef"
```

---

### Task 4: Versioned SwiftData schema and V1 → V2 migration

**Files:**
- Delete: `UcapHutang/Data/Persistence/SwiftDataEntities.swift`
- Create: `UcapHutang/Data/Persistence/SchemaV1.swift`
- Create: `UcapHutang/Data/Persistence/SchemaV2.swift`
- Create: `UcapHutang/Data/Persistence/PersistenceModels.swift`
- Create: `UcapHutang/Data/Persistence/UcapHutangMigrationPlan.swift`
- Replace: `UcapHutang/App/AppContainer.swift`
- Create: `UcapHutangTests/SchemaMigrationV2Tests.swift`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `enum SchemaV1: VersionedSchema` (version 1.0.0) with nested `SDTransactionParticipant`, `SDTransactionDraft`, `SDLedgerEntry` — identical to the previous `SwiftDataEntities.swift`.
  - `enum SchemaV2: VersionedSchema` (version 2.0.0) — V1 plus `SDTransactionDraft.includesUser: Bool = true` and `SDLedgerEntry.contactIdentifier: String? = nil` (both also init parameters with those defaults, `contactIdentifier` last).
  - `typealias SDTransactionParticipant = SchemaV2.SDTransactionParticipant` (same for `SDTransactionDraft`, `SDLedgerEntry`).
  - `enum UcapHutangMigrationPlan: SchemaMigrationPlan` with `static func applyV2DataRules(in context: ModelContext) throws`.
  - `AppContainer.makeDefault()` opens `Schema(versionedSchema: SchemaV2.self)` with the migration plan.

- [ ] **Step 1: Write the failing migration test**

Create `UcapHutangTests/SchemaMigrationV2Tests.swift`:

```swift
import XCTest
import SwiftData
@testable import UcapHutang

@MainActor
final class SchemaMigrationV2Tests: XCTestCase {
    func testMigratingUnversionedV1StorePurgesDiscardedDraftsAndBackfillsContactIdentifiers() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("UcapHutangMigration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("default.store")

        let keptDraftID = UUID()
        let discardedDraftID = UUID()

        // 1. Create a store exactly like the pre-versioning app did: a plain Schema of the V1 models.
        do {
            let v1Schema = Schema([
                SchemaV1.SDTransactionParticipant.self,
                SchemaV1.SDTransactionDraft.self,
                SchemaV1.SDLedgerEntry.self
            ])
            let v1Container = try SwiftData.ModelContainer(
                for: v1Schema,
                configurations: ModelConfiguration(schema: v1Schema, url: storeURL)
            )
            let context = ModelContext(v1Container)

            context.insert(SchemaV1.SDTransactionDraft(
                id: keptDraftID,
                statusRaw: "confirmed",
                flowRaw: "personal",
                typeRaw: "piutang",
                title: "Kopi",
                totalAmount: 20_000,
                rawTranscript: "Satria ngutang 20 ribu beli kopi",
                participants: [SchemaV1.SDTransactionParticipant(name: "Satria", contactIdentifier: "contact-satria", shareAmount: 20_000)]
            ))
            context.insert(SchemaV1.SDTransactionDraft(
                id: discardedDraftID,
                statusRaw: "discarded",
                flowRaw: "personal",
                typeRaw: "hutang",
                title: "Bensin",
                totalAmount: 50_000,
                rawTranscript: "transkrip yang sudah dihapus user",
                participants: [SchemaV1.SDTransactionParticipant(name: "Dito", shareAmount: 50_000)]
            ))
            context.insert(SchemaV1.SDLedgerEntry(personID: "contact-satria", personName: "Satria", kindRaw: "charge", balanceDelta: 20_000, title: "Kopi", sourceDraftID: keptDraftID))
            context.insert(SchemaV1.SDLedgerEntry(personID: "contact-satria", personName: "Satria", kindRaw: "payment", balanceDelta: -5_000, title: "Bayar"))
            context.insert(SchemaV1.SDLedgerEntry(personID: "budi", personName: "Budi", kindRaw: "charge", balanceDelta: -10_000, title: "Pulsa"))
            try context.save()
        }

        // 2. Reopen the same file with the versioned schema and the migration plan.
        let v2Schema = Schema(versionedSchema: SchemaV2.self)
        let v2Container = try SwiftData.ModelContainer(
            for: v2Schema,
            migrationPlan: UcapHutangMigrationPlan.self,
            configurations: ModelConfiguration(schema: v2Schema, url: storeURL)
        )
        let context = ModelContext(v2Container)

        let drafts = try context.fetch(FetchDescriptor<SchemaV2.SDTransactionDraft>())
        XCTAssertEqual(drafts.map(\.id), [keptDraftID], "Discarded drafts must be purged")
        XCTAssertEqual(drafts.first?.includesUser, true)

        let participants = try context.fetch(FetchDescriptor<SchemaV2.SDTransactionParticipant>())
        XCTAssertEqual(participants.map(\.name), ["Satria"], "Participants of purged drafts must be gone")

        let entries = try context.fetch(FetchDescriptor<SchemaV2.SDLedgerEntry>())
        let satriaEntries = entries.filter { $0.personID == "contact-satria" }
        XCTAssertEqual(satriaEntries.count, 2)
        XCTAssertTrue(satriaEntries.allSatisfy { $0.contactIdentifier == "contact-satria" }, "Charges and payments of a linked person get backfilled")
        let budi = entries.first { $0.personID == "budi" }
        XCTAssertNotNil(budi)
        XCTAssertNil(budi?.contactIdentifier, "Legacy unlinked people stay unlinked")
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run the single test class command with `<Class>` = `SchemaMigrationV2Tests`.

Expected: `error:` lines such as `cannot find 'SchemaV1' in scope`, then `** TEST FAILED **`.

- [ ] **Step 3: Replace the entity file with versioned schemas**

```bash
git rm UcapHutang/Data/Persistence/SwiftDataEntities.swift
```

Create `UcapHutang/Data/Persistence/SchemaV1.swift`:

```swift
import Foundation
import SwiftData

/// Frozen copy of the SwiftData models that shipped before schema versioning.
/// NEVER edit this file: SwiftData uses it to recognize and migrate old stores.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [SDTransactionParticipant.self, SDTransactionDraft.self, SDLedgerEntry.self]
    }

    @Model
    final class SDTransactionParticipant {
        @Attribute(.unique) var id: UUID
        var name: String
        var contactIdentifier: String?
        var shareAmount: Int64
        var itemTitle: String?
        var notes: String?

        init(
            id: UUID = UUID(),
            name: String,
            contactIdentifier: String? = nil,
            shareAmount: Int64 = 0,
            itemTitle: String? = nil,
            notes: String? = nil
        ) {
            self.id = id
            self.name = name
            self.contactIdentifier = contactIdentifier
            self.shareAmount = shareAmount
            self.itemTitle = itemTitle
            self.notes = notes
        }
    }

    @Model
    final class SDTransactionDraft {
        @Attribute(.unique) var id: UUID
        var statusRaw: String
        var flowRaw: String
        var typeRaw: String
        var transactionDate: Date
        var title: String
        var totalAmount: Int64
        var splitMethodRaw: String?
        var notes: String?
        var rawTranscript: String
        var rawModelResponse: String?
        var reviewWarningsRaw: [String]
        var createdAt: Date

        @Relationship(deleteRule: .cascade)
        var participants: [SDTransactionParticipant]

        init(
            id: UUID = UUID(),
            statusRaw: String = "needsReview",
            flowRaw: String = "personal",
            typeRaw: String = "hutang",
            transactionDate: Date = Date(),
            title: String = "",
            totalAmount: Int64 = 0,
            splitMethodRaw: String? = nil,
            notes: String? = nil,
            rawTranscript: String = "",
            rawModelResponse: String? = nil,
            reviewWarningsRaw: [String] = [],
            createdAt: Date = Date(),
            participants: [SDTransactionParticipant] = []
        ) {
            self.id = id
            self.statusRaw = statusRaw
            self.flowRaw = flowRaw
            self.typeRaw = typeRaw
            self.transactionDate = transactionDate
            self.title = title
            self.totalAmount = totalAmount
            self.splitMethodRaw = splitMethodRaw
            self.notes = notes
            self.rawTranscript = rawTranscript
            self.rawModelResponse = rawModelResponse
            self.reviewWarningsRaw = reviewWarningsRaw
            self.createdAt = createdAt
            self.participants = participants
        }
    }

    @Model
    final class SDLedgerEntry {
        @Attribute(.unique) var id: UUID
        var personID: String
        var personName: String
        var kindRaw: String
        var balanceDelta: Int64
        var date: Date
        var title: String
        var notes: String?
        var sourceDraftID: UUID?

        init(
            id: UUID = UUID(),
            personID: String,
            personName: String,
            kindRaw: String,
            balanceDelta: Int64,
            date: Date = Date(),
            title: String,
            notes: String? = nil,
            sourceDraftID: UUID? = nil
        ) {
            self.id = id
            self.personID = personID
            self.personName = personName
            self.kindRaw = kindRaw
            self.balanceDelta = balanceDelta
            self.date = date
            self.title = title
            self.notes = notes
            self.sourceDraftID = sourceDraftID
        }
    }
}
```

Create `UcapHutang/Data/Persistence/SchemaV2.swift`:

```swift
import Foundation
import SwiftData

/// Current SwiftData models. App code refers to them through the typealiases in `PersistenceModels.swift`.
enum SchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [SDTransactionParticipant.self, SDTransactionDraft.self, SDLedgerEntry.self]
    }

    @Model
    final class SDTransactionParticipant {
        @Attribute(.unique) var id: UUID
        var name: String
        var contactIdentifier: String?
        var shareAmount: Int64
        var itemTitle: String?
        var notes: String?

        init(
            id: UUID = UUID(),
            name: String,
            contactIdentifier: String? = nil,
            shareAmount: Int64 = 0,
            itemTitle: String? = nil,
            notes: String? = nil
        ) {
            self.id = id
            self.name = name
            self.contactIdentifier = contactIdentifier
            self.shareAmount = shareAmount
            self.itemTitle = itemTitle
            self.notes = notes
        }
    }

    @Model
    final class SDTransactionDraft {
        @Attribute(.unique) var id: UUID
        var statusRaw: String
        var flowRaw: String
        var typeRaw: String
        var transactionDate: Date
        var title: String
        var totalAmount: Int64
        var splitMethodRaw: String?
        var includesUser: Bool = true
        var notes: String?
        var rawTranscript: String
        var rawModelResponse: String?
        var reviewWarningsRaw: [String]
        var createdAt: Date

        @Relationship(deleteRule: .cascade)
        var participants: [SDTransactionParticipant]

        init(
            id: UUID = UUID(),
            statusRaw: String = "needsReview",
            flowRaw: String = "personal",
            typeRaw: String = "hutang",
            transactionDate: Date = Date(),
            title: String = "",
            totalAmount: Int64 = 0,
            splitMethodRaw: String? = nil,
            includesUser: Bool = true,
            notes: String? = nil,
            rawTranscript: String = "",
            rawModelResponse: String? = nil,
            reviewWarningsRaw: [String] = [],
            createdAt: Date = Date(),
            participants: [SDTransactionParticipant] = []
        ) {
            self.id = id
            self.statusRaw = statusRaw
            self.flowRaw = flowRaw
            self.typeRaw = typeRaw
            self.transactionDate = transactionDate
            self.title = title
            self.totalAmount = totalAmount
            self.splitMethodRaw = splitMethodRaw
            self.includesUser = includesUser
            self.notes = notes
            self.rawTranscript = rawTranscript
            self.rawModelResponse = rawModelResponse
            self.reviewWarningsRaw = reviewWarningsRaw
            self.createdAt = createdAt
            self.participants = participants
        }
    }

    @Model
    final class SDLedgerEntry {
        @Attribute(.unique) var id: UUID
        var personID: String
        var personName: String
        var kindRaw: String
        var balanceDelta: Int64
        var date: Date
        var title: String
        var notes: String?
        var sourceDraftID: UUID?
        var contactIdentifier: String? = nil

        init(
            id: UUID = UUID(),
            personID: String,
            personName: String,
            kindRaw: String,
            balanceDelta: Int64,
            date: Date = Date(),
            title: String,
            notes: String? = nil,
            sourceDraftID: UUID? = nil,
            contactIdentifier: String? = nil
        ) {
            self.id = id
            self.personID = personID
            self.personName = personName
            self.kindRaw = kindRaw
            self.balanceDelta = balanceDelta
            self.date = date
            self.title = title
            self.notes = notes
            self.sourceDraftID = sourceDraftID
            self.contactIdentifier = contactIdentifier
        }
    }
}
```

Create `UcapHutang/Data/Persistence/PersistenceModels.swift`:

```swift
import SwiftData

typealias SDTransactionParticipant = SchemaV2.SDTransactionParticipant
typealias SDTransactionDraft = SchemaV2.SDTransactionDraft
typealias SDLedgerEntry = SchemaV2.SDLedgerEntry
```

Create `UcapHutang/Data/Persistence/UcapHutangMigrationPlan.swift`:

```swift
import Foundation
import SwiftData

enum UcapHutangMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    static var migrateV1toV2: MigrationStage {
        MigrationStage.custom(
            fromVersion: SchemaV1.self,
            toVersion: SchemaV2.self,
            willMigrate: nil,
            didMigrate: { context in
                try UcapHutangMigrationPlan.applyV2DataRules(in: context)
            }
        )
    }

    /// V1 → V2 data rules (spec §6.5):
    /// 1. Permanently delete drafts that were soft-deleted ("discarded"), including their participants.
    /// 2. Backfill `SDLedgerEntry.contactIdentifier`: a `personID` counts as linked when it equals
    ///    the `contactIdentifier` of any remaining stored participant.
    static func applyV2DataRules(in context: ModelContext) throws {
        let discarded = "discarded"
        let discardedDrafts = try context.fetch(FetchDescriptor<SchemaV2.SDTransactionDraft>(
            predicate: #Predicate { $0.statusRaw == discarded }
        ))
        for draft in discardedDrafts {
            for participant in draft.participants {
                context.delete(participant)
            }
        }
        try context.save()
        for draft in discardedDrafts {
            context.delete(draft)
        }
        try context.save()

        let participants = try context.fetch(FetchDescriptor<SchemaV2.SDTransactionParticipant>())
        let linkedIdentifiers = Set(participants.compactMap(\.contactIdentifier))

        let entries = try context.fetch(FetchDescriptor<SchemaV2.SDLedgerEntry>())
        for entry in entries {
            entry.contactIdentifier = linkedIdentifiers.contains(entry.personID) ? entry.personID : nil
        }
        try context.save()
    }
}
```

- [ ] **Step 4: Open the real store with the versioned schema**

Replace the entire content of `UcapHutang/App/AppContainer.swift` with:

```swift
import Foundation
import Observation
import SwiftData

@Observable
final class AppContainer {
    let repository: any TransactionRepository
    let extractionService: any DraftExtractionService
    let storageErrorMessage: String?

    init(
        repository: any TransactionRepository,
        extractionService: any DraftExtractionService,
        storageErrorMessage: String? = nil
    ) {
        self.repository = repository
        self.extractionService = extractionService
        self.storageErrorMessage = storageErrorMessage
    }

    static func makeDefault() -> AppContainer {
        let schema = Schema(versionedSchema: SchemaV2.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: UcapHutangMigrationPlan.self,
                configurations: config
            )
            let repo = SwiftDataTransactionRepository(modelContainer: container)
            let extraction = HybridQwenExtractionService(llmClient: MLXQwenClient())
            return AppContainer(repository: repo, extractionService: extraction)
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
                storageErrorMessage: message
            )
        }
    }
}
```

- [ ] **Step 5: Run to verify it passes**

Run the single test class command with `<Class>` = `SchemaMigrationV2Tests`. Expected: `Executed 1 test, with 0 failures`.

If instead the test fails with a SwiftData error mentioning "unknown model version" or "Cannot use staged migration", **stop and report** the full error to the developer (do not change `SchemaV1`).

Run the full test command. Expected: `Executed 44 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add UcapHutang/Data/Persistence/SchemaV1.swift UcapHutang/Data/Persistence/SchemaV2.swift UcapHutang/Data/Persistence/PersistenceModels.swift UcapHutang/Data/Persistence/UcapHutangMigrationPlan.swift UcapHutang/App/AppContainer.swift UcapHutangTests/SchemaMigrationV2Tests.swift
git commit -m "feat: version SwiftData schema and migrate V1 stores to V2"
```

(`git rm` already staged the deletion of `SwiftDataEntities.swift`.)

---

### Task 5: Repository API — delete, pending count, link/merge, payment guard

**Files:**
- Replace: `UcapHutang/Domain/Protocols/TransactionRepository.swift`
- Replace: `UcapHutang/Data/Persistence/InMemoryTransactionRepository.swift`
- Replace: `UcapHutang/Data/Persistence/SwiftDataTransactionRepository.swift`
- Modify: `UcapHutang/Domain/Models/TransactionModels.swift` (remove `DraftStatus.discarded`)
- Modify: `UcapHutang/Features/Review/ViewModels/ReviewListViewModel.swift`
- Modify: `UcapHutang/Features/Review/ViewModels/ReviewDetailViewModel.swift`
- Modify: `UcapHutang/Features/Review/Legacy/ReviewDraftViewModel.swift` (one line)
- Modify: `UcapHutang/Features/Riwayat/ViewModels/LedgerListViewModel.swift`
- Modify: `UcapHutang/Features/Riwayat/ViewModels/PersonLedgerDetailViewModel.swift`
- Create: `UcapHutangTests/RepositoryLinkAndDeleteTests.swift`

**Interfaces:**
- Consumes: `ContactRef` (Task 3), `LedgerEntry.contactIdentifier`, `PersonLedgerSummary.contactIdentifier` (Task 3), `SDLedgerEntry.contactIdentifier`, `SDTransactionDraft.includesUser` (Task 4), `DraftValidator.validateForConfirmation` (Task 2).
- Produces (P3–P6 rely on these exact signatures):

  ```swift
  protocol TransactionRepository: Sendable {
      func draftsNeedingReview() async throws -> [TransactionDraft]
      func pendingDraftCount() async throws -> Int
      func draft(id: UUID) async throws -> TransactionDraft?
      func saveDraft(_ draft: TransactionDraft) async throws
      func deleteDraft(id: UUID) async throws
      func confirmDraft(_ draft: TransactionDraft) async throws
      func ledgerEntries() async throws -> [LedgerEntry]
      func linkedContactIdentifiers() async throws -> [String]
      func linkPerson(personID: String, to contact: ContactRef) async throws
      func recordPayment(for person: PersonLedgerSummary, amount: Int64, date: Date, notes: String?) async throws
  }
  enum RepositoryError: LocalizedError { case invalidAmount, paymentExceedsBalance, noOutstandingBalance, personNotLinked, personNotFound }
  ```

  Semantics:
  - `deleteDraft` physically removes the draft (and, in SwiftData, its participants). Unknown IDs are a no-op.
  - Every charge written by `confirmDraft` stores `contactIdentifier = participant.contactIdentifier`.
  - `linkedContactIdentifiers()` returns distinct non-nil ledger `contactIdentifier`s, sorted ascending.
  - `linkPerson` moves every entry of `personID` **and** every entry already under `contact.identifier` to `personID = contact.identifier`, `personName = contact.displayName`, `contactIdentifier = contact.identifier`, in one save; throws `personNotFound` if `personID` has no entries.
  - `recordPayment` throws `personNotLinked` if the person has entries but none has a `contactIdentifier`; the payment entry copies that identifier.
  - `LedgerListViewModel` summaries and `PersonLedgerDetailViewModel.reload()` fill `PersonLedgerSummary.contactIdentifier` with the first non-nil identifier among the person's entries.

- [ ] **Step 1: Write the failing tests**

Create `UcapHutangTests/RepositoryLinkAndDeleteTests.swift`:

```swift
import XCTest
import SwiftData
@testable import UcapHutang

@MainActor
final class RepositoryLinkAndDeleteTests: XCTestCase {
    private struct Subject {
        let label: String
        let repository: any TransactionRepository
        let container: SwiftData.ModelContainer?
    }

    /// Returns the in-memory actor repository and a SwiftData repository (in-memory store), both seeded with `entries`.
    private func makeSubjects(seedEntries entries: [LedgerEntry] = []) throws -> [Subject] {
        let inMemory = InMemoryTransactionRepository(seedEntries: entries)

        let schema = Schema(versionedSchema: SchemaV2.self)
        let container = try SwiftData.ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        for entry in entries {
            container.mainContext.insert(SDLedgerEntry(
                id: entry.id,
                personID: entry.personID,
                personName: entry.personName,
                kindRaw: entry.kind.rawValue,
                balanceDelta: entry.balanceDelta,
                date: entry.date,
                title: entry.title,
                notes: entry.notes,
                sourceDraftID: entry.sourceDraftID,
                contactIdentifier: entry.contactIdentifier
            ))
        }
        try container.mainContext.save()
        let swiftData = SwiftDataTransactionRepository(modelContainer: container)

        return [
            Subject(label: "InMemory", repository: inMemory, container: nil),
            Subject(label: "SwiftData", repository: swiftData, container: container)
        ]
    }

    private func linkedPersonalDraft(name: String = "Satria", contact: String = "contact-satria") -> TransactionDraft {
        TransactionDraft(
            flow: .personal,
            type: .piutang,
            title: "Kopi",
            totalAmount: 20_000,
            participants: [TransactionParticipant(name: name, contactIdentifier: contact, shareAmount: 20_000)],
            rawTranscript: "\(name) ngutang 20 ribu beli kopi"
        )
    }

    private func legacyEntry(_ personID: String, _ name: String, _ delta: Int64, kind: LedgerEntryKind = .charge, contact: String? = nil) -> LedgerEntry {
        LedgerEntry(personID: personID, personName: name, kind: kind, balanceDelta: delta, date: .now, title: "Pulsa", contactIdentifier: contact)
    }

    func testPendingDraftCountCountsOnlyDraftsNeedingReview() async throws {
        for subject in try makeSubjects() {
            let pending = linkedPersonalDraft(name: "Ari", contact: "contact-ari")
            let confirmed = linkedPersonalDraft()
            try await subject.repository.saveDraft(pending)
            try await subject.repository.saveDraft(confirmed)
            try await subject.repository.confirmDraft(confirmed)

            let count = try await subject.repository.pendingDraftCount()
            XCTAssertEqual(count, 1, subject.label)
        }
    }

    func testDeleteDraftRemovesDraftPermanently() async throws {
        for subject in try makeSubjects() {
            let draft = linkedPersonalDraft()
            try await subject.repository.saveDraft(draft)

            try await subject.repository.deleteDraft(id: draft.id)

            let stored = try await subject.repository.draft(id: draft.id)
            XCTAssertNil(stored, subject.label)
            let count = try await subject.repository.pendingDraftCount()
            XCTAssertEqual(count, 0, subject.label)
            if let container = subject.container {
                let participants = try container.mainContext.fetch(FetchDescriptor<SDTransactionParticipant>())
                XCTAssertTrue(participants.isEmpty, "\(subject.label): participants must be deleted with the draft")
            }
        }
    }

    func testConfirmStoresContactIdentifierOnEveryCharge() async throws {
        for subject in try makeSubjects() {
            let draft = TransactionDraft(
                flow: .splitBill,
                type: .splitBill,
                title: "Makan malam",
                totalAmount: 90_000,
                splitMethod: .equal,
                participants: [
                    TransactionParticipant(name: "Satria", contactIdentifier: "contact-satria", shareAmount: 30_000),
                    TransactionParticipant(name: "Ari", contactIdentifier: "contact-ari", shareAmount: 30_000)
                ],
                rawTranscript: "Aku bayarin makan malam 90 ribu sama Satria dan Ari"
            )
            try await subject.repository.saveDraft(draft)
            try await subject.repository.confirmDraft(draft)

            let entries = try await subject.repository.ledgerEntries()
            XCTAssertEqual(entries.count, 2, subject.label)
            XCTAssertTrue(entries.allSatisfy { $0.contactIdentifier == $0.personID }, subject.label)
        }
    }

    func testLinkedContactIdentifiersAreDistinctAndSorted() async throws {
        let seed = [
            legacyEntry("contact-b", "Bima", 10_000, contact: "contact-b"),
            legacyEntry("contact-b", "Bima", -2_000, kind: .payment, contact: "contact-b"),
            legacyEntry("contact-a", "Ari", 5_000, contact: "contact-a"),
            legacyEntry("budi", "Budi", -10_000)
        ]
        for subject in try makeSubjects(seedEntries: seed) {
            let identifiers = try await subject.repository.linkedContactIdentifiers()
            XCTAssertEqual(identifiers, ["contact-a", "contact-b"], subject.label)
        }
    }

    func testLinkPersonMovesLegacyEntriesToTheContact() async throws {
        let seed = [
            legacyEntry("budi", "Budi", -10_000),
            legacyEntry("budi", "Budi", 4_000, kind: .payment)
        ]
        for subject in try makeSubjects(seedEntries: seed) {
            let contact = ContactRef(identifier: "contact-budi", displayName: "Budi Santoso", phoneNumber: nil)
            try await subject.repository.linkPerson(personID: "budi", to: contact)

            let entries = try await subject.repository.ledgerEntries()
            XCTAssertEqual(entries.count, 2, subject.label)
            XCTAssertTrue(entries.allSatisfy { $0.personID == "contact-budi" }, subject.label)
            XCTAssertTrue(entries.allSatisfy { $0.personName == "Budi Santoso" }, subject.label)
            XCTAssertTrue(entries.allSatisfy { $0.contactIdentifier == "contact-budi" }, subject.label)
        }
    }

    func testLinkPersonMergesIntoExistingContactHistoryAndUnifiesName() async throws {
        let seed = [
            legacyEntry("budi", "Budi", -10_000),
            legacyEntry("contact-budi", "Budi S", 25_000, contact: "contact-budi")
        ]
        for subject in try makeSubjects(seedEntries: seed) {
            let contact = ContactRef(identifier: "contact-budi", displayName: "Budi Santoso", phoneNumber: nil)
            try await subject.repository.linkPerson(personID: "budi", to: contact)

            let entries = try await subject.repository.ledgerEntries()
            XCTAssertEqual(entries.count, 2, subject.label)
            XCTAssertTrue(entries.allSatisfy { $0.personID == "contact-budi" && $0.personName == "Budi Santoso" }, subject.label)
            XCTAssertEqual(entries.reduce(Int64(0)) { $0 + $1.balanceDelta }, 15_000, subject.label)
        }
    }

    func testLinkPersonWithUnknownPersonThrowsPersonNotFound() async throws {
        for subject in try makeSubjects(seedEntries: [legacyEntry("budi", "Budi", -10_000)]) {
            let contact = ContactRef(identifier: "contact-x", displayName: "X", phoneNumber: nil)
            do {
                try await subject.repository.linkPerson(personID: "nobody", to: contact)
                XCTFail("\(subject.label): expected personNotFound")
            } catch RepositoryError.personNotFound {
                // Expected.
            } catch {
                XCTFail("\(subject.label): unexpected error \(error)")
            }
        }
    }

    func testRecordPaymentOnUnlinkedPersonThrowsPersonNotLinked() async throws {
        for subject in try makeSubjects(seedEntries: [legacyEntry("budi", "Budi", -10_000)]) {
            let summary = PersonLedgerSummary(id: "budi", displayName: "Budi", balance: -10_000, entryCount: 1, lastActivity: .now)
            do {
                try await subject.repository.recordPayment(for: summary, amount: 5_000, date: .now, notes: nil)
                XCTFail("\(subject.label): expected personNotLinked")
            } catch RepositoryError.personNotLinked {
                // Expected.
            } catch {
                XCTFail("\(subject.label): unexpected error \(error)")
            }
            let entries = try await subject.repository.ledgerEntries()
            XCTAssertEqual(entries.count, 1, subject.label)
        }
    }

    func testLedgerSummariesCarryContactIdentifier() async throws {
        let repository = InMemoryTransactionRepository(seedEntries: [
            legacyEntry("budi", "Budi", -10_000),
            legacyEntry("contact-ari", "Ari", 5_000, contact: "contact-ari")
        ])
        let viewModel = LedgerListViewModel(repository: repository)

        await viewModel.load()

        let byID = Dictionary(uniqueKeysWithValues: viewModel.summaries.map { ($0.id, $0) })
        XCTAssertEqual(byID["contact-ari"]?.isLinked, true)
        XCTAssertEqual(byID["budi"]?.isLinked, false)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run the single test class command with `<Class>` = `RepositoryLinkAndDeleteTests`.

Expected: `error:` lines such as `value of type 'any TransactionRepository' has no member 'pendingDraftCount'`, `... 'deleteDraft'`, `... 'linkPerson'`, then `** TEST FAILED **`.

- [ ] **Step 3: Replace the protocol**

Replace the entire content of `UcapHutang/Domain/Protocols/TransactionRepository.swift` with:

```swift
import Foundation

extension Notification.Name {
    static let transactionRepositoryDidChange = Notification.Name("transactionRepositoryDidChange")
}

protocol TransactionRepository: Sendable {
    func draftsNeedingReview() async throws -> [TransactionDraft]
    func pendingDraftCount() async throws -> Int
    func draft(id: UUID) async throws -> TransactionDraft?
    func saveDraft(_ draft: TransactionDraft) async throws
    /// Permanently deletes the draft and its participants. Unknown IDs are ignored.
    func deleteDraft(id: UUID) async throws
    func confirmDraft(_ draft: TransactionDraft) async throws
    func ledgerEntries() async throws -> [LedgerEntry]
    /// Distinct, sorted contact identifiers that already have ledger history.
    func linkedContactIdentifiers() async throws -> [String]
    /// Moves every entry of `personID` (and every entry already under the contact) to the contact identity.
    func linkPerson(personID: String, to contact: ContactRef) async throws
    func recordPayment(for person: PersonLedgerSummary, amount: Int64, date: Date, notes: String?) async throws
}

enum RepositoryError: LocalizedError {
    case invalidAmount
    case paymentExceedsBalance
    case noOutstandingBalance
    case personNotLinked
    case personNotFound

    var errorDescription: String? {
        switch self {
        case .invalidAmount: "Nominal harus lebih dari nol."
        case .paymentExceedsBalance: "Pembayaran tidak boleh melewati saldo saat ini."
        case .noOutstandingBalance: "Saldo orang ini sudah lunas atau tidak lagi tersedia. Muat ulang Riwayat."
        case .personNotLinked: "Hubungkan orang ini ke kontak sebelum mencatat pembayaran."
        case .personNotFound: "Orang ini tidak ditemukan di Riwayat. Muat ulang Riwayat."
        }
    }
}
```

- [ ] **Step 4: Remove `DraftStatus.discarded`**

In `UcapHutang/Domain/Models/TransactionModels.swift`, replace:

```swift
enum DraftStatus: String, Codable, Sendable {
    case needsReview
    case confirmed
    case discarded
}
```

with:

```swift
enum DraftStatus: String, Codable, Sendable {
    case needsReview
    case confirmed
}
```

- [ ] **Step 5: Replace `InMemoryTransactionRepository.swift`**

Replace the entire content of `UcapHutang/Data/Persistence/InMemoryTransactionRepository.swift` with:

```swift
import Foundation

actor InMemoryTransactionRepository: TransactionRepository {
    private var drafts: [UUID: TransactionDraft]
    private var entries: [LedgerEntry]

    init(seedDrafts: [TransactionDraft] = [], seedEntries: [LedgerEntry] = []) {
        drafts = Dictionary(uniqueKeysWithValues: seedDrafts.map { ($0.id, $0) })
        entries = seedEntries
    }

    func draftsNeedingReview() -> [TransactionDraft] {
        drafts.values
            .filter { $0.status == .needsReview }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func pendingDraftCount() -> Int {
        drafts.values.filter { $0.status == .needsReview }.count
    }

    func draft(id: UUID) -> TransactionDraft? { drafts[id] }

    func saveDraft(_ draft: TransactionDraft) {
        drafts[draft.id] = draft
        notifyChange()
    }

    func deleteDraft(id: UUID) {
        guard drafts.removeValue(forKey: id) != nil else { return }
        notifyChange()
    }

    func confirmDraft(_ input: TransactionDraft) throws {
        try DraftValidator.validateForConfirmation(input)
        if drafts[input.id]?.status == .confirmed { return }
        if entries.contains(where: { $0.sourceDraftID == input.id }) {
            drafts[input.id]?.status = .confirmed
            return
        }
        var draft = input
        draft.status = .confirmed
        drafts[draft.id] = draft

        switch draft.type {
        case .unknown:
            throw RepositoryError.invalidAmount
        case .hutang, .piutang:
            guard let participant = draft.participants.first else { return }
            let magnitude = draft.totalAmount
            let delta = draft.type == .piutang ? magnitude : -magnitude
            entries.append(makeCharge(draft: draft, participant: participant, delta: delta))
        case .splitBill:
            for participant in draft.participants {
                entries.append(makeCharge(draft: draft, participant: participant, delta: participant.shareAmount))
            }
        }
        notifyChange()
    }

    func ledgerEntries() -> [LedgerEntry] { entries.sorted { $0.date > $1.date } }

    func linkedContactIdentifiers() -> [String] {
        Array(Set(entries.compactMap(\.contactIdentifier))).sorted()
    }

    func linkPerson(personID: String, to contact: ContactRef) throws {
        guard entries.contains(where: { $0.personID == personID }) else {
            throw RepositoryError.personNotFound
        }
        for index in entries.indices
        where entries[index].personID == personID || entries[index].personID == contact.identifier {
            entries[index].personID = contact.identifier
            entries[index].personName = contact.displayName
            entries[index].contactIdentifier = contact.identifier
        }
        notifyChange()
    }

    func recordPayment(for person: PersonLedgerSummary, amount: Int64, date: Date, notes: String?) throws {
        guard amount > 0 else { throw RepositoryError.invalidAmount }
        let personEntries = entries.filter { $0.personID == person.id }
        let contactIdentifier = personEntries.lazy.compactMap(\.contactIdentifier).first
        guard personEntries.isEmpty || contactIdentifier != nil else {
            throw RepositoryError.personNotLinked
        }
        let latestBalance = personEntries.reduce(Int64(0)) { $0 + $1.balanceDelta }
        guard latestBalance != 0 else { throw RepositoryError.noOutstandingBalance }
        guard amount <= abs(latestBalance) else { throw RepositoryError.paymentExceedsBalance }
        let delta = latestBalance > 0 ? -amount : amount
        entries.append(LedgerEntry(
            personID: person.id,
            personName: person.displayName,
            kind: .payment,
            balanceDelta: delta,
            date: date,
            title: "Bayar",
            notes: notes,
            contactIdentifier: contactIdentifier
        ))
        notifyChange()
    }

    private func notifyChange() {
        Task { @MainActor in
            NotificationCenter.default.post(name: .transactionRepositoryDidChange, object: nil)
        }
    }

    private func makeCharge(draft: TransactionDraft, participant: TransactionParticipant, delta: Int64) -> LedgerEntry {
        LedgerEntry(
            personID: participant.contactIdentifier ?? participant.name.lowercased(),
            personName: participant.name,
            kind: .charge,
            balanceDelta: delta,
            date: draft.transactionDate,
            title: draft.title,
            notes: draft.notes,
            sourceDraftID: draft.id,
            contactIdentifier: participant.contactIdentifier
        )
    }
}
```

- [ ] **Step 6: Replace `SwiftDataTransactionRepository.swift`**

Replace the entire content of `UcapHutang/Data/Persistence/SwiftDataTransactionRepository.swift` with:

```swift
import Foundation
import SwiftData

@MainActor
final class SwiftDataTransactionRepository: TransactionRepository {
    private let modelContainer: ModelContainer
    private var context: ModelContext { modelContainer.mainContext }

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: .transactionRepositoryDidChange, object: nil)
    }

    func draftsNeedingReview() async throws -> [TransactionDraft] {
        let statusNeedsReview = DraftStatus.needsReview.rawValue
        let descriptor = FetchDescriptor<SDTransactionDraft>(
            predicate: #Predicate { $0.statusRaw == statusNeedsReview },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map(Self.toDomain)
    }

    func pendingDraftCount() async throws -> Int {
        let statusNeedsReview = DraftStatus.needsReview.rawValue
        let descriptor = FetchDescriptor<SDTransactionDraft>(
            predicate: #Predicate { $0.statusRaw == statusNeedsReview }
        )
        return try context.fetchCount(descriptor)
    }

    func draft(id: UUID) async throws -> TransactionDraft? {
        try fetchDraftEntity(id: id).map(Self.toDomain)
    }

    func saveDraft(_ draft: TransactionDraft) async throws {
        if let existing = try fetchDraftEntity(id: draft.id) {
            apply(draft, to: existing)
        } else {
            context.insert(makeDraftEntity(from: draft))
        }
        try context.save()
        notifyChange()
    }

    func deleteDraft(id: UUID) async throws {
        guard let existing = try fetchDraftEntity(id: id) else { return }
        for participant in existing.participants {
            context.delete(participant)
        }
        context.delete(existing)
        try context.save()
        notifyChange()
    }

    func confirmDraft(_ input: TransactionDraft) async throws {
        try DraftValidator.validateForConfirmation(input)
        let inputID = input.id

        // 1. Already confirmed → idempotent no-op.
        let existingDraft = try fetchDraftEntity(id: inputID)
        if let existingDraft, existingDraft.statusRaw == DraftStatus.confirmed.rawValue {
            return
        }

        // 2. Ledger already written for this draft → only fix the status.
        let ledgerDescriptor = FetchDescriptor<SDLedgerEntry>(predicate: #Predicate { $0.sourceDraftID == inputID })
        guard try context.fetch(ledgerDescriptor).isEmpty else {
            if let existingDraft {
                existingDraft.statusRaw = DraftStatus.confirmed.rawValue
                try context.save()
            }
            return
        }

        var draft = input
        draft.status = .confirmed
        if let existingDraft {
            apply(draft, to: existingDraft)
        } else {
            context.insert(makeDraftEntity(from: draft))
        }

        switch draft.type {
        case .unknown:
            throw RepositoryError.invalidAmount
        case .hutang, .piutang:
            guard let participant = draft.participants.first else { break }
            let magnitude = draft.totalAmount
            let delta = draft.type == .piutang ? magnitude : -magnitude
            context.insert(makeCharge(draft: draft, participant: participant, delta: delta))
        case .splitBill:
            for participant in draft.participants {
                context.insert(makeCharge(draft: draft, participant: participant, delta: participant.shareAmount))
            }
        }

        // Atomic commit for draft status + ledger entries.
        try context.save()
        notifyChange()
    }

    func ledgerEntries() async throws -> [LedgerEntry] {
        let descriptor = FetchDescriptor<SDLedgerEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return try context.fetch(descriptor).map(Self.toDomain)
    }

    func linkedContactIdentifiers() async throws -> [String] {
        let entries = try context.fetch(FetchDescriptor<SDLedgerEntry>())
        return Array(Set(entries.compactMap(\.contactIdentifier))).sorted()
    }

    func linkPerson(personID: String, to contact: ContactRef) async throws {
        let oldID = personID
        let newID = contact.identifier
        let descriptor = FetchDescriptor<SDLedgerEntry>(
            predicate: #Predicate { $0.personID == oldID || $0.personID == newID }
        )
        let affected = try context.fetch(descriptor)
        guard affected.contains(where: { $0.personID == oldID }) else {
            throw RepositoryError.personNotFound
        }
        for entry in affected {
            entry.personID = newID
            entry.personName = contact.displayName
            entry.contactIdentifier = newID
        }
        try context.save()
        notifyChange()
    }

    func recordPayment(for person: PersonLedgerSummary, amount: Int64, date: Date, notes: String?) async throws {
        guard amount > 0 else { throw RepositoryError.invalidAmount }
        let personID = person.id
        let personEntries = try context.fetch(
            FetchDescriptor<SDLedgerEntry>(predicate: #Predicate { $0.personID == personID })
        )
        let contactIdentifier = personEntries.lazy.compactMap(\.contactIdentifier).first
        guard personEntries.isEmpty || contactIdentifier != nil else {
            throw RepositoryError.personNotLinked
        }
        let latestBalance = personEntries.reduce(Int64(0)) { $0 + $1.balanceDelta }
        guard latestBalance != 0 else { throw RepositoryError.noOutstandingBalance }
        guard amount <= abs(latestBalance) else { throw RepositoryError.paymentExceedsBalance }
        let delta = latestBalance > 0 ? -amount : amount
        context.insert(SDLedgerEntry(
            id: UUID(),
            personID: person.id,
            personName: person.displayName,
            kindRaw: LedgerEntryKind.payment.rawValue,
            balanceDelta: delta,
            date: date,
            title: "Bayar",
            notes: notes,
            contactIdentifier: contactIdentifier
        ))
        try context.save()
        notifyChange()
    }

    // MARK: - Mapping helpers

    private func fetchDraftEntity(id: UUID) throws -> SDTransactionDraft? {
        let draftID = id
        let descriptor = FetchDescriptor<SDTransactionDraft>(predicate: #Predicate { $0.id == draftID })
        return try context.fetch(descriptor).first
    }

    private func apply(_ draft: TransactionDraft, to entity: SDTransactionDraft) {
        entity.statusRaw = draft.status.rawValue
        entity.flowRaw = draft.flow.rawValue
        entity.typeRaw = draft.type.rawValue
        entity.transactionDate = draft.transactionDate
        entity.title = draft.title
        entity.totalAmount = draft.totalAmount
        entity.splitMethodRaw = draft.splitMethod?.rawValue
        entity.includesUser = draft.includesUser
        entity.notes = draft.notes
        entity.rawTranscript = draft.rawTranscript
        entity.rawModelResponse = draft.rawModelResponse
        entity.reviewWarningsRaw = draft.reviewWarnings
        entity.participants = makeParticipantEntities(from: draft)
    }

    private func makeDraftEntity(from draft: TransactionDraft) -> SDTransactionDraft {
        SDTransactionDraft(
            id: draft.id,
            statusRaw: draft.status.rawValue,
            flowRaw: draft.flow.rawValue,
            typeRaw: draft.type.rawValue,
            transactionDate: draft.transactionDate,
            title: draft.title,
            totalAmount: draft.totalAmount,
            splitMethodRaw: draft.splitMethod?.rawValue,
            includesUser: draft.includesUser,
            notes: draft.notes,
            rawTranscript: draft.rawTranscript,
            rawModelResponse: draft.rawModelResponse,
            reviewWarningsRaw: draft.reviewWarnings,
            createdAt: draft.createdAt,
            participants: makeParticipantEntities(from: draft)
        )
    }

    private func makeParticipantEntities(from draft: TransactionDraft) -> [SDTransactionParticipant] {
        draft.participants.map {
            SDTransactionParticipant(
                id: $0.id,
                name: $0.name,
                contactIdentifier: $0.contactIdentifier,
                shareAmount: $0.shareAmount,
                itemTitle: $0.itemTitle,
                notes: $0.notes
            )
        }
    }

    private func makeCharge(draft: TransactionDraft, participant: TransactionParticipant, delta: Int64) -> SDLedgerEntry {
        SDLedgerEntry(
            id: UUID(),
            personID: participant.contactIdentifier ?? participant.name.lowercased(),
            personName: participant.name,
            kindRaw: LedgerEntryKind.charge.rawValue,
            balanceDelta: delta,
            date: draft.transactionDate,
            title: draft.title,
            notes: draft.notes,
            sourceDraftID: draft.id,
            contactIdentifier: participant.contactIdentifier
        )
    }

    private static func toDomain(_ sd: SDTransactionDraft) -> TransactionDraft {
        TransactionDraft(
            id: sd.id,
            status: DraftStatus(rawValue: sd.statusRaw) ?? .needsReview,
            flow: CaptureFlow(rawValue: sd.flowRaw) ?? .personal,
            type: TransactionType(rawValue: sd.typeRaw) ?? .hutang,
            transactionDate: sd.transactionDate,
            title: sd.title,
            totalAmount: sd.totalAmount,
            splitMethod: sd.splitMethodRaw.flatMap(SplitMethod.init(rawValue:)),
            includesUser: sd.includesUser,
            participants: sd.participants.map {
                TransactionParticipant(
                    id: $0.id,
                    name: $0.name,
                    contactIdentifier: $0.contactIdentifier,
                    shareAmount: $0.shareAmount,
                    itemTitle: $0.itemTitle,
                    notes: $0.notes
                )
            },
            notes: sd.notes,
            rawTranscript: sd.rawTranscript,
            rawModelResponse: sd.rawModelResponse,
            reviewWarnings: sd.reviewWarningsRaw,
            createdAt: sd.createdAt
        )
    }

    private static func toDomain(_ sd: SDLedgerEntry) -> LedgerEntry {
        LedgerEntry(
            id: sd.id,
            personID: sd.personID,
            personName: sd.personName,
            kind: LedgerEntryKind(rawValue: sd.kindRaw) ?? .charge,
            balanceDelta: sd.balanceDelta,
            date: sd.date,
            title: sd.title,
            notes: sd.notes,
            sourceDraftID: sd.sourceDraftID,
            contactIdentifier: sd.contactIdentifier
        )
    }
}
```

- [ ] **Step 7: Update callers of the removed `discardDraft`**

In `UcapHutang/Features/Review/ViewModels/ReviewListViewModel.swift`, replace:

```swift
            try? await repository.discardDraft(id: id)
```

with:

```swift
            try? await repository.deleteDraft(id: id)
```

In `UcapHutang/Features/Review/ViewModels/ReviewDetailViewModel.swift`, replace:

```swift
            try? await repository.discardDraft(id: draftID)
```

with:

```swift
            try? await repository.deleteDraft(id: draftID)
```

In `UcapHutang/Features/Review/Legacy/ReviewDraftViewModel.swift`, replace:

```swift
            try await repository.discardDraft(id: draftID)
```

with:

```swift
            try await repository.deleteDraft(id: draftID)
```

Then confirm no caller remains:

```bash
grep -rn --include='*.swift' -E "discardDraft|\.discarded" UcapHutang UcapHutangTests
```

Expected: **no output**.

- [ ] **Step 8: Fill `contactIdentifier` in ledger summaries**

In `UcapHutang/Features/Riwayat/ViewModels/LedgerListViewModel.swift`, replace:

```swift
            return PersonLedgerSummary(
                id: id,
                displayName: latest.personName,
                balance: values.reduce(0) { $0 + $1.balanceDelta },
                entryCount: values.count,
                lastActivity: latest.date
            )
```

with:

```swift
            return PersonLedgerSummary(
                id: id,
                displayName: latest.personName,
                balance: values.reduce(0) { $0 + $1.balanceDelta },
                entryCount: values.count,
                lastActivity: latest.date,
                contactIdentifier: values.lazy.compactMap(\.contactIdentifier).first
            )
```

In `UcapHutang/Features/Riwayat/ViewModels/PersonLedgerDetailViewModel.swift`, replace:

```swift
        person = PersonLedgerSummary(
            id: person.id,
            displayName: latestName,
            balance: currentEntries.reduce(Int64(0)) { $0 + $1.balanceDelta },
            entryCount: currentEntries.count,
            lastActivity: currentEntries.first?.date ?? person.lastActivity
        )
```

with:

```swift
        person = PersonLedgerSummary(
            id: person.id,
            displayName: latestName,
            balance: currentEntries.reduce(Int64(0)) { $0 + $1.balanceDelta },
            entryCount: currentEntries.count,
            lastActivity: currentEntries.first?.date ?? person.lastActivity,
            contactIdentifier: currentEntries.lazy.compactMap(\.contactIdentifier).first
        )
```

- [ ] **Step 9: Run to verify it passes**

Run the single test class command with `<Class>` = `RepositoryLinkAndDeleteTests`. Expected: `Executed 9 tests, with 0 failures`.

Run the full test command. Expected: `Executed 53 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 10: Commit**

```bash
git add UcapHutang/Domain/Protocols/TransactionRepository.swift UcapHutang/Domain/Models/TransactionModels.swift UcapHutang/Data/Persistence/InMemoryTransactionRepository.swift UcapHutang/Data/Persistence/SwiftDataTransactionRepository.swift UcapHutang/Features/Review/ViewModels/ReviewListViewModel.swift UcapHutang/Features/Review/ViewModels/ReviewDetailViewModel.swift UcapHutang/Features/Review/Legacy/ReviewDraftViewModel.swift UcapHutang/Features/Riwayat/ViewModels/LedgerListViewModel.swift UcapHutang/Features/Riwayat/ViewModels/PersonLedgerDetailViewModel.swift UcapHutangTests/RepositoryLinkAndDeleteTests.swift
git commit -m "feat: add permanent delete, pending count, contact link/merge and payment guard"
```

---

## Phase exit checklist

- [ ] `git status --porcelain` shows only `?? .xcede/` and `?? xcede.yml`.
- [ ] `git log --oneline -5` shows the five P2 commits.
- [ ] Full test command: `Executed 53 tests, with 0 failures`, `** TEST SUCCEEDED **`.
- [ ] **Developer device check (do not skip; report to the developer):** on a device or simulator that already has data from the pre-P2 app, install the P2 build and open it once. Expected: the app opens normally (no "Migrasi data ke versi terbaru gagal" screen), Riwayat balances are unchanged, and drafts that had been deleted earlier no longer exist. The agent cannot perform this check itself; ask the developer to confirm before starting P3.
