# P1 — Feature-First MVVM Restructure Implementation Plan

> **For agentic workers (Gemini 3.7 Flash):** Execute the tasks in order, one step at a time. Steps use checkbox (`- [ ]`) syntax — tick each one as you finish it. When a step gives a complete file, replace the **entire** file content with it (do not merge by hand). If an actual result differs from the "Expected" text, stop and report instead of improvising.

**Goal:** Move every file into the approved feature-first MVVM folder structure, rename the Draft feature to Review, and migrate state management from `ObservableObject`/Combine to `@Observable` — without changing app behavior (the only visible change is the first tab's label and icon).

**Architecture:** Views own their ViewModel with `@State`; ViewModels are `@Observable` classes (the target's default actor isolation is already `MainActor`). The app container is injected with `.environment(_:)` and read with `@Environment(AppContainer.self)`. Folders: `App/`, `Core/`, `Domain/`, `Data/`, `Services/`, `Features/<Feature>/{Views,ViewModels,Components,Models}`. The old Catat-path review screen is parked in `Features/Review/Legacy/` until P3 deletes it.

**Tech Stack:** Swift 5 language mode, SwiftUI (iOS 26.5), Observation framework, SwiftData, XCTest, Xcode 26.6.

**Spec:** `docs/superpowers/specs/2026-09-12-voice-draft-remediation-design.md` (§3 decisions log, §5, §14 P1).

## Global Constraints

- Work on branch `fix/all`. Do not create or switch branches.
- **P0 must be finished first** (`docs/superpowers/plans/2026-09-12-p0-contact-link-guard.md`); the suite must have 21 passing tests.
- **Never stage `.xcede/` or `xcede.yml`.** Always `git add` explicit paths or use `git mv`; never `git add -A`, `git add .`, or `git commit -a`.
- Do not edit `UcapHutang.xcodeproj/project.pbxproj`. Both targets use file-system-synchronized groups: moving a `.swift` file on disk is enough.
- Build settings in effect (do not change): `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_VERSION = 5.0`, `IPHONEOS_DEPLOYMENT_TARGET = 26.5`.
- **No behavior change.** Do not "fix" mock data, fallback strings ("Teman", "5 menit lalu", `["E","C","D"]`), layout, colors, fonts, or copy in this phase — those are handled in P3 and P7. The only allowed visible change is the first tab: label **"Review"**, SF Symbol **`doc.badge.clock`**.
- Files inside `UcapHutang/Features/Review/Legacy/` are moved only; never edit their contents in P1 (they keep `ObservableObject`, `import Combine`, `Int: @retroactive Identifiable`, and `Array[safe:]` until P3 deletes them).
- Domain and data names stay unchanged: `TransactionDraft`, `DraftStatus`, `DraftValidator`, `TransactionRepository`, `draftsNeedingReview()`, `saveDraft(_:)`, etc.
- Money is `Int64`. User-facing strings stay Indonesian and byte-for-byte identical.
- Full test command:

  ```bash
  xcodebuild test -project UcapHutang.xcodeproj -scheme UcapHutang -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | grep -E "Test Case '.*' (passed|failed)|error:|Executed [0-9]+ tests|TEST SUCCEEDED|TEST FAILED"
  ```

  Expected after every task in this phase: `Executed 21 tests, with 0 failures` and `** TEST SUCCEEDED **`. A compile error shows up as `error:` lines followed by `** TEST FAILED **`.

## Final file map for this phase

```
UcapHutang/
├── App/            AppContainer.swift, ContentView.swift, RootTabView.swift
├── UcapHutangApp.swift                      (stays at target root)
├── Core/
│   ├── DesignSystem/  AppDesignSystem.swift, FilteredCardListView.swift
│   ├── Extensions/    Int64+Rupiah.swift
│   └── Utilities/     SplitCalculationEngine.swift
├── Domain/
│   ├── Models/        TransactionModels.swift
│   ├── Protocols/     TransactionRepository.swift
│   └── Validation/    DraftValidator.swift
├── Data/
│   └── Persistence/   SwiftDataEntities.swift, SwiftDataTransactionRepository.swift, InMemoryTransactionRepository.swift
├── Services/
│   ├── AI/            DraftExtractionService.swift, MLXQwenClient.swift, QwenOutputDecoder.swift, TransactionDateResolver.swift
│   ├── Contacts/      ContactResolutionService.swift
│   └── Speech/        SpeechRecognizer.swift
└── Features/
    ├── Catat/
    │   ├── Views/       CatatFlowChooserView.swift, CatatView.swift
    │   └── ViewModels/  CatatViewModel.swift
    ├── Review/
    │   ├── Views/       ReviewListView.swift, ReviewDetailView.swift, ReviewContactPickerSheet.swift
    │   ├── ViewModels/  ReviewListViewModel.swift, ReviewDetailViewModel.swift, ReviewContactPickerViewModel.swift
    │   ├── Components/  ReviewCardView.swift, SmartContactCardView.swift, SplitParticipantRow.swift
    │   ├── Models/      ReviewUIModels.swift
    │   └── Legacy/      ReviewDraftView.swift, ReviewDraftViewModel.swift, ContactPickerSheet.swift
    └── Riwayat/
        ├── Views/       LedgerListView.swift, PersonLedgerDetailView.swift, PaymentView.swift
        ├── ViewModels/  LedgerListViewModel.swift, PersonLedgerDetailViewModel.swift
        ├── Components/  DetailEntryCardRow.swift, LedgerFilterPill.swift, PersonCardRow.swift
        └── Models/      LedgerUIModels.swift
```

---

### Task 0: Preconditions

**Files:** none changed.

- [ ] **Step 1: Confirm the developer resolved `QwenOutputDecoder.swift`**

Run:

```bash
git status --porcelain -- UcapHutang/Core/Utilities/QwenOutputDecoder.swift
```

Expected: **no output**. If it prints anything (for example ` M UcapHutang/Core/Utilities/QwenOutputDecoder.swift`), **STOP the phase** and tell the developer: "P1 needs `UcapHutang/Core/Utilities/QwenOutputDecoder.swift` to be committed or discarded by you before I can move it." Do not commit, stash, or revert it yourself.

- [ ] **Step 2: Confirm P0 is done and the tree is clean**

Run:

```bash
git status --porcelain
```

Expected: only `?? .xcede/` and `?? xcede.yml`.

Run the full test command. Expected: `Executed 21 tests, with 0 failures`, `** TEST SUCCEEDED **`.

---

### Task 1: Move core, domain, data, and service files

**Files:**
- Move: `UcapHutang/ContentView.swift` → `UcapHutang/App/ContentView.swift`
- Move: `UcapHutang/Domain/Models/DraftValidator.swift` → `UcapHutang/Domain/Validation/DraftValidator.swift`
- Move: `UcapHutang/Domain/Models/SwiftDataEntities.swift` → `UcapHutang/Data/Persistence/SwiftDataEntities.swift`
- Move: `UcapHutang/Domain/Repositories/SwiftDataTransactionRepository.swift` → `UcapHutang/Data/Persistence/SwiftDataTransactionRepository.swift`
- Move + modify: `UcapHutang/Domain/Repositories/TransactionRepository.swift` → `UcapHutang/Domain/Protocols/TransactionRepository.swift`
- Create: `UcapHutang/Data/Persistence/InMemoryTransactionRepository.swift`
- Move: `UcapHutang/Core/Utilities/QwenOutputDecoder.swift` → `UcapHutang/Services/AI/QwenOutputDecoder.swift`
- Move: `UcapHutang/Core/Utilities/TransactionDateResolver.swift` → `UcapHutang/Services/AI/TransactionDateResolver.swift`
- Create: `UcapHutang/Core/Extensions/Int64+Rupiah.swift`
- Modify: `UcapHutang/Domain/Models/TransactionModels.swift:97-101`

**Interfaces:**
- Consumes: nothing new.
- Produces: same types and signatures as before, in new locations. `extension Int64 { var rupiahFormatted: String }` now lives in `Core/Extensions/Int64+Rupiah.swift`. `actor InMemoryTransactionRepository` now lives in `Data/Persistence/InMemoryTransactionRepository.swift`.

- [ ] **Step 1: Create folders and move files with git**

```bash
mkdir -p UcapHutang/Domain/Validation UcapHutang/Domain/Protocols UcapHutang/Data/Persistence UcapHutang/Core/Extensions
git mv UcapHutang/ContentView.swift UcapHutang/App/ContentView.swift
git mv UcapHutang/Domain/Models/DraftValidator.swift UcapHutang/Domain/Validation/DraftValidator.swift
git mv UcapHutang/Domain/Models/SwiftDataEntities.swift UcapHutang/Data/Persistence/SwiftDataEntities.swift
git mv UcapHutang/Domain/Repositories/SwiftDataTransactionRepository.swift UcapHutang/Data/Persistence/SwiftDataTransactionRepository.swift
git mv UcapHutang/Domain/Repositories/TransactionRepository.swift UcapHutang/Domain/Protocols/TransactionRepository.swift
git mv UcapHutang/Core/Utilities/QwenOutputDecoder.swift UcapHutang/Services/AI/QwenOutputDecoder.swift
git mv UcapHutang/Core/Utilities/TransactionDateResolver.swift UcapHutang/Services/AI/TransactionDateResolver.swift
rmdir UcapHutang/Domain/Repositories
```

Expected: every command succeeds silently. `rmdir` succeeds because the folder is now empty.

- [ ] **Step 2: Split the repository protocol file**

Replace the entire content of `UcapHutang/Domain/Protocols/TransactionRepository.swift` with:

```swift
import Foundation

extension Notification.Name {
    static let transactionRepositoryDidChange = Notification.Name("transactionRepositoryDidChange")
}

protocol TransactionRepository: Sendable {
    func draftsNeedingReview() async throws -> [TransactionDraft]
    func draft(id: UUID) async throws -> TransactionDraft?
    func saveDraft(_ draft: TransactionDraft) async throws
    func discardDraft(id: UUID) async throws
    func confirmDraft(_ draft: TransactionDraft) async throws
    func ledgerEntries() async throws -> [LedgerEntry]
    func recordPayment(for person: PersonLedgerSummary, amount: Int64, date: Date, notes: String?) async throws
}

enum RepositoryError: LocalizedError {
    case invalidAmount
    case paymentExceedsBalance
    case noOutstandingBalance

    var errorDescription: String? {
        switch self {
        case .invalidAmount: "Nominal harus lebih dari nol."
        case .paymentExceedsBalance: "Pembayaran tidak boleh melewati saldo saat ini."
        case .noOutstandingBalance: "Saldo orang ini sudah lunas atau tidak lagi tersedia. Muat ulang Riwayat."
        }
    }
}
```

Create `UcapHutang/Data/Persistence/InMemoryTransactionRepository.swift` with:

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

    func draft(id: UUID) -> TransactionDraft? { drafts[id] }

    func saveDraft(_ draft: TransactionDraft) {
        drafts[draft.id] = draft
        notifyChange()
    }

    func discardDraft(id: UUID) {
        guard var draft = drafts[id] else { return }
        draft.status = .discarded
        drafts[id] = draft
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

    func recordPayment(for person: PersonLedgerSummary, amount: Int64, date: Date, notes: String?) throws {
        guard amount > 0 else { throw RepositoryError.invalidAmount }
        let latestBalance = entries.filter { $0.personID == person.id }.reduce(Int64(0)) { $0 + $1.balanceDelta }
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
            notes: notes
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
            sourceDraftID: draft.id
        )
    }
}
```

- [ ] **Step 3: Move the Rupiah formatter into Core/Extensions**

Create `UcapHutang/Core/Extensions/Int64+Rupiah.swift` with:

```swift
import Foundation

extension Int64 {
    var rupiahFormatted: String {
        "Rp. " + formatted(.number.locale(Locale(identifier: "id_ID")).precision(.fractionLength(0)))
    }
}
```

In `UcapHutang/Domain/Models/TransactionModels.swift`, delete exactly this block (and the blank line before it) at the end of the file:

```swift
extension Int64 {
    var rupiahFormatted: String {
        "Rp. " + formatted(.number.locale(Locale(identifier: "id_ID")).precision(.fractionLength(0)))
    }
}
```

The file must now end with the closing `}` of `struct PersonLedgerSummary`.

- [ ] **Step 4: Build and test**

Run the full test command. Expected: `Executed 21 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add UcapHutang/Domain/Protocols/TransactionRepository.swift UcapHutang/Data/Persistence/InMemoryTransactionRepository.swift UcapHutang/Core/Extensions/Int64+Rupiah.swift UcapHutang/Domain/Models/TransactionModels.swift
git commit -m "refactor: move core, domain, data and AI files into layered folders"
```

(`git mv` already staged the renames; `git commit` includes them.)

---

### Task 2: Riwayat feature (was Ledger) + `@Observable`

**Files:**
- Move: `UcapHutang/Features/Ledger/` → `UcapHutang/Features/Riwayat/`
- Move: `UcapHutang/Features/Riwayat/Views/Components/*` → `UcapHutang/Features/Riwayat/Components/`
- Replace: `UcapHutang/Features/Riwayat/ViewModels/LedgerListViewModel.swift`
- Replace: `UcapHutang/Features/Riwayat/ViewModels/PersonLedgerDetailViewModel.swift`
- Replace: `UcapHutang/Features/Riwayat/Views/LedgerListView.swift`
- Replace: `UcapHutang/Features/Riwayat/Views/PersonLedgerDetailView.swift`
- Replace: `UcapHutang/Features/Riwayat/Components/PersonCardRow.swift`
- Replace: `UcapHutang/Features/Riwayat/Components/DetailEntryCardRow.swift`
- Unchanged content: `PaymentView.swift`, `LedgerFilterPill.swift`, `LedgerUIModels.swift`

**Interfaces:**
- Consumes: `TransactionRepository`, `LedgerEntry`, `PersonLedgerSummary`, `LedgerFilter`, `DetailFilter`, `Int64.rupiahFormatted`.
- Produces:
  - `@Observable final class LedgerListViewModel` — `init(repository: any TransactionRepository)`, `summaries`, `filter`, `searchQuery`, `totalReceivable`, `receivableCount`, `totalDebt`, `debtCount`, `filteredSummaries`, `errorMessage`, `load() async`, `entries(for:)`.
  - `@Observable final class PersonLedgerDetailViewModel` — `init(person:entries:repository:)`, `person`, `entries`, `selectedFilter`, `showingPayment`, `filteredEntries`, `reload() async`, **`reminderMessageURL: URL?`** (replaces `sendReminderMessage()`; the View opens it).
  - `struct LedgerListView: View` — `init(repository: any TransactionRepository)` (unchanged).

- [ ] **Step 1: Move the folder**

```bash
git mv UcapHutang/Features/Ledger UcapHutang/Features/Riwayat
mkdir -p UcapHutang/Features/Riwayat/Components
git mv UcapHutang/Features/Riwayat/Views/Components/DetailEntryCardRow.swift UcapHutang/Features/Riwayat/Components/DetailEntryCardRow.swift
git mv UcapHutang/Features/Riwayat/Views/Components/LedgerFilterPill.swift UcapHutang/Features/Riwayat/Components/LedgerFilterPill.swift
git mv UcapHutang/Features/Riwayat/Views/Components/PersonCardRow.swift UcapHutang/Features/Riwayat/Components/PersonCardRow.swift
rmdir UcapHutang/Features/Riwayat/Views/Components
```

- [ ] **Step 2: Replace `LedgerListViewModel.swift`**

Full content of `UcapHutang/Features/Riwayat/ViewModels/LedgerListViewModel.swift`:

```swift
import Foundation
import Observation

@Observable
final class LedgerListViewModel {
    private(set) var summaries: [PersonLedgerSummary] = []
    private(set) var entries: [LedgerEntry] = []
    var filter: LedgerFilter = .all
    var searchQuery: String = ""
    var errorMessage: String?

    private let repository: any TransactionRepository

    init(repository: any TransactionRepository) {
        self.repository = repository
    }

    var totalReceivable: Int64 {
        summaries.filter { $0.balance > 0 }.reduce(0) { $0 + $1.balance }
    }

    var receivableCount: Int {
        summaries.filter { $0.balance > 0 }.count
    }

    var totalDebt: Int64 {
        abs(summaries.filter { $0.balance < 0 }.reduce(0) { $0 + $1.balance })
    }

    var debtCount: Int {
        summaries.filter { $0.balance < 0 }.count
    }

    var filteredSummaries: [PersonLedgerSummary] {
        summaries.filter { person in
            let matchesFilter: Bool
            switch filter {
            case .all:
                matchesFilter = true
            case .receivable:
                matchesFilter = person.balance > 0
            case .debt:
                matchesFilter = person.balance < 0
            }

            let matchesSearch: Bool
            if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                matchesSearch = true
            } else {
                matchesSearch = person.displayName.localizedCaseInsensitiveContains(searchQuery)
            }

            return matchesFilter && matchesSearch
        }
    }

    func load() async {
        do {
            entries = try await repository.ledgerEntries()
            summaries = Self.summarize(entries)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func entries(for person: PersonLedgerSummary) -> [LedgerEntry] {
        entries.filter { $0.personID == person.id }.sorted { $0.date > $1.date }
    }

    private static func summarize(_ entries: [LedgerEntry]) -> [PersonLedgerSummary] {
        Dictionary(grouping: entries, by: \.personID).compactMap { id, values in
            guard let latest = values.max(by: { $0.date < $1.date }) else { return nil }
            return PersonLedgerSummary(
                id: id,
                displayName: latest.personName,
                balance: values.reduce(0) { $0 + $1.balanceDelta },
                entryCount: values.count,
                lastActivity: latest.date
            )
        }
        .sorted { $0.lastActivity > $1.lastActivity }
    }
}
```

- [ ] **Step 3: Replace `PersonLedgerDetailViewModel.swift`**

Full content of `UcapHutang/Features/Riwayat/ViewModels/PersonLedgerDetailViewModel.swift`:

```swift
import Foundation
import Observation

@Observable
final class PersonLedgerDetailViewModel {
    private(set) var person: PersonLedgerSummary
    private(set) var entries: [LedgerEntry]
    var selectedFilter: DetailFilter = .all
    var showingPayment: Bool = false

    private let repository: any TransactionRepository

    init(person: PersonLedgerSummary, entries: [LedgerEntry], repository: any TransactionRepository) {
        self.person = person
        self.entries = entries
        self.repository = repository
    }

    var filteredEntries: [LedgerEntry] {
        entries.filter { entry in
            switch selectedFilter {
            case .all:
                return true
            case .piutang:
                return entry.kind == .charge && entry.balanceDelta > 0
            case .utang:
                return entry.kind == .charge && entry.balanceDelta < 0
            case .bayar:
                return entry.kind == .payment
            }
        }
    }

    /// The `sms:` URL the View opens with `openURL`. ViewModels never call UIKit directly.
    var reminderMessageURL: URL? {
        let text = "Halo \(person.displayName), mengingatkan kembali ada catatan saldo \(abs(person.balance).rupiahFormatted) di UcapHutang ya."
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "sms:&body=\(encoded)")
    }

    func reload() async {
        guard let allEntries = try? await repository.ledgerEntries() else { return }
        let currentEntries = allEntries.filter { $0.personID == person.id }.sorted { $0.date > $1.date }
        let latestName = currentEntries.first?.personName ?? person.displayName
        entries = currentEntries
        person = PersonLedgerSummary(
            id: person.id,
            displayName: latestName,
            balance: currentEntries.reduce(Int64(0)) { $0 + $1.balanceDelta },
            entryCount: currentEntries.count,
            lastActivity: currentEntries.first?.date ?? person.lastActivity
        )
    }
}
```

Note: `abs(person.balance).rupiahFormatted` produces the same text as the removed `NumberFormatter` code (`"Rp. 20.000"`).

- [ ] **Step 4: Replace `LedgerListView.swift`**

Full content of `UcapHutang/Features/Riwayat/Views/LedgerListView.swift`:

```swift
import SwiftUI

struct LedgerListView: View {
    @State private var viewModel: LedgerListViewModel
    private let repository: any TransactionRepository

    init(repository: any TransactionRepository) {
        self.repository = repository
        _viewModel = State(initialValue: LedgerListViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Title
                        Text("Ringkasan Saldo")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Color.primary)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        // 2 Metric Summary Cards
                        HStack(spacing: 12) {
                            // Piutang
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.down.left")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.green)
                                    Text("Piutang")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.green)
                                }

                                Text(viewModel.totalReceivable.rupiahFormatted)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(Color.green)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)

                                Text("\(viewModel.receivableCount) orang berutang")
                                    .font(.caption)
                                    .foregroundStyle(Color.secondary)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                            // Utang
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.up.right")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.red)
                                    Text("Utang")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.red)
                                }

                                Text(viewModel.totalDebt.rupiahFormatted)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(Color.red)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)

                                Text("\(viewModel.debtCount) tanggungan aktif")
                                    .font(.caption)
                                    .foregroundStyle(Color.secondary)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .padding(.horizontal, 20)

                        // Filter Pills
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(LedgerFilter.allCases) { filter in
                                    LedgerFilterPill(
                                        filter: filter,
                                        isSelected: viewModel.filter == filter
                                    ) {
                                        viewModel.filter = filter
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        // Person Card List
                        if viewModel.filteredSummaries.isEmpty {
                            AppEmptyState(
                                icon: "book.closed",
                                title: "Belum ada riwayat",
                                message: "Data yang sudah dikonfirmasi akan dikelompokkan per orang."
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.top, 30)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.filteredSummaries) { person in
                                    NavigationLink(value: person) {
                                        PersonCardRow(person: person)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 80)
                }

                // Bottom Search Bar Floating
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.secondary)

                    TextField("Cari nama orang", text: $viewModel.searchQuery)
                        .font(.body)

                    Image(systemName: "mic")
                        .foregroundStyle(Color.secondary)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
                .background(Color(.systemBackground))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color(.separator), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: PersonLedgerSummary.self) { person in
                PersonLedgerDetailView(person: person, entries: viewModel.entries(for: person), repository: repository)
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
            .onReceive(NotificationCenter.default.publisher(for: .transactionRepositoryDidChange)) { _ in
                Task { await viewModel.load() }
            }
        }
    }
}
```

- [ ] **Step 5: Replace `PersonLedgerDetailView.swift`**

Full content of `UcapHutang/Features/Riwayat/Views/PersonLedgerDetailView.swift`:

```swift
import SwiftUI

struct PersonLedgerDetailView: View {
    @State private var viewModel: PersonLedgerDetailViewModel
    @Environment(\.openURL) private var openURL
    private let repository: any TransactionRepository

    init(person: PersonLedgerSummary, entries: [LedgerEntry], repository: any TransactionRepository) {
        self.repository = repository
        _viewModel = State(initialValue: PersonLedgerDetailViewModel(
            person: person,
            entries: entries,
            repository: repository
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Hero Saldo Card
                VStack(alignment: .leading, spacing: 12) {
                    // Status Tag
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.person.balance >= 0 ? Color.green : Color.red)
                            .frame(width: 8, height: 8)

                        Text(viewModel.person.balance >= 0 ? "Dia berutang padamu" : "Kamu berutang padanya")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(viewModel.person.balance >= 0 ? Color.green : Color.red)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background((viewModel.person.balance >= 0 ? Color.green : Color.red).opacity(0.12))
                    .clipShape(Capsule())

                    // Big Balance Text
                    Text(abs(viewModel.person.balance).rupiahFormatted)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color.primary)

                    // Ingatkan Action Button
                    Button {
                        if let url = viewModel.reminderMessageURL {
                            openURL(url)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "message.fill")
                                .font(.subheadline)
                            Text("Ingatkan lewat iMessage")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Color(red: 1.0, green: 0.96, blue: 0.88))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(.separator), lineWidth: 1)
                )
                .padding(.horizontal, 20)

                // Detail Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(DetailFilter.allCases) { filter in
                            DetailFilterPill(
                                filter: filter,
                                isSelected: viewModel.selectedFilter == filter
                            ) {
                                viewModel.selectedFilter = filter
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Section Title: Riwayat Catatan
                Text("Riwayat Catatan")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                // History Entries List
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.filteredEntries) { entry in
                        DetailEntryCardRow(entry: entry)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(viewModel.person.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Catat Bayar") {
                    viewModel.showingPayment = true
                }
                .font(.subheadline.weight(.medium))
            }
        }
        .sheet(isPresented: $viewModel.showingPayment) {
            PaymentView(person: viewModel.person, repository: repository) {
                viewModel.showingPayment = false
                Task { await viewModel.reload() }
            }
        }
        .task { await viewModel.reload() }
        .onReceive(NotificationCenter.default.publisher(for: .transactionRepositoryDidChange)) { _ in
            Task { await viewModel.reload() }
        }
    }
}
```

- [ ] **Step 6: Replace `PersonCardRow.swift` and `DetailEntryCardRow.swift`**

Full content of `UcapHutang/Features/Riwayat/Components/PersonCardRow.swift`:

```swift
import SwiftUI

struct PersonCardRow: View {
    let person: PersonLedgerSummary

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(person.displayName)
                    .font(.body.weight(.bold))
                    .foregroundStyle(Color.primary)

                Text("\(person.entryCount) Catatan")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                if person.balance == 0 {
                    Text("Lunas")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                } else if person.balance > 0 {
                    Text(person.balance.rupiahFormatted)
                        .font(.body.weight(.bold))
                        .foregroundStyle(Color.green)
                } else {
                    Text(abs(person.balance).rupiahFormatted)
                        .font(.body.weight(.bold))
                        .foregroundStyle(Color.red)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondary.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }
}
```

Full content of `UcapHutang/Features/Riwayat/Components/DetailEntryCardRow.swift`:

```swift
import SwiftUI

struct DetailEntryCardRow: View {
    let entry: LedgerEntry

    var body: some View {
        HStack(spacing: 12) {
            // Icon Bubble
            ZStack {
                Circle()
                    .fill(bubbleColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: bubbleIcon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(bubbleColor)
            }

            // Title & Date
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.body.weight(.bold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Text(formatDate(entry.date))
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            // Amount
            Text(abs(entry.balanceDelta).rupiahFormatted)
                .font(.body.weight(.bold))
                .foregroundStyle(bubbleColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }

    private var isPayment: Bool {
        entry.kind == .payment
    }

    private var bubbleColor: Color {
        if isPayment {
            return Color.blue
        } else if entry.balanceDelta >= 0 {
            return Color.green
        } else {
            return Color.red
        }
    }

    private var bubbleIcon: String {
        if isPayment {
            return "creditcard.fill"
        } else if entry.balanceDelta >= 0 {
            return "arrow.down.left"
        } else {
            return "arrow.up.right"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
}
```

- [ ] **Step 7: Build and test**

Run the full test command. Expected: `Executed 21 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 8: Commit**

```bash
git add UcapHutang/Features/Riwayat
git commit -m "refactor: rename Ledger feature to Riwayat and adopt @Observable"
```

---

### Task 3: Review feature (replaces Draft) + Legacy parking + `@Observable`

**Files:**
- Move: `UcapHutang/Features/Review/ReviewDraftView.swift`, `ReviewDraftViewModel.swift`, `ContactPickerSheet.swift` → `UcapHutang/Features/Review/Legacy/` (content unchanged)
- Move + replace: `UcapHutang/Features/Draft/Models/DraftUIModels.swift` → `UcapHutang/Features/Review/Models/ReviewUIModels.swift`
- Move + replace: `UcapHutang/Features/Draft/ViewModels/DraftListViewModel.swift` → `UcapHutang/Features/Review/ViewModels/ReviewListViewModel.swift`
- Move + replace: `UcapHutang/Features/Draft/ViewModels/DraftReviewViewModel.swift` → `UcapHutang/Features/Review/ViewModels/ReviewDetailViewModel.swift`
- Move + replace: `UcapHutang/Features/Draft/ViewModels/DraftContactPickerViewModel.swift` → `UcapHutang/Features/Review/ViewModels/ReviewContactPickerViewModel.swift`
- Move + replace: `UcapHutang/Features/Draft/DraftListView.swift` → `UcapHutang/Features/Review/Views/ReviewListView.swift`
- Move + replace: `UcapHutang/Features/Draft/Views/DraftReviewView.swift` → `UcapHutang/Features/Review/Views/ReviewDetailView.swift`
- Move + replace: `UcapHutang/Features/Draft/Views/DraftContactPickerSheet.swift` → `UcapHutang/Features/Review/Views/ReviewContactPickerSheet.swift`
- Move + replace: `UcapHutang/Features/Draft/Views/Components/DraftCardView.swift` → `UcapHutang/Features/Review/Components/ReviewCardView.swift`
- Move + replace: `UcapHutang/Features/Draft/Views/Components/SmartContactCardView.swift` → `UcapHutang/Features/Review/Components/SmartContactCardView.swift`
- Move (content unchanged): `UcapHutang/Features/Draft/Views/Components/SplitParticipantRow.swift` → `UcapHutang/Features/Review/Components/SplitParticipantRow.swift`
- Move (content unchanged): `UcapHutang/Features/Components.swift` → `UcapHutang/Core/DesignSystem/FilteredCardListView.swift`
- Modify: `UcapHutang/App/RootTabView.swift` (two type names)

**Interfaces:**
- Consumes: `TransactionRepository`, `TransactionType`, `Int64.rupiahFormatted`, `FilteredCardListView`, `AppEmptyState`, `AppColors`, `IdentifiableUUID` (defined in `App/RootTabView.swift`).
- Produces (used by P3):
  - `enum ReviewFilterType`, `enum ContactLinkState`, `struct ReviewItemUIModel`, `struct ReviewParticipantUIModel`, `struct ContactUIModel`, `struct SelectedContactUIModel`, `enum ReviewMockData`.
  - `@Observable final class ReviewListViewModel` — `init(repository: (any TransactionRepository)? = nil, previewDrafts: [ReviewItemUIModel]? = nil)`.
  - `@Observable final class ReviewDetailViewModel` — `init(draftID:repository:initialType:initialNominal:initialDescription:initialParticipants:)` (same defaults as before).
  - `@Observable final class ReviewContactPickerViewModel` — `init(isMultiSelect:totalAmount:initialSelected:recentContacts:deviceContacts:)`.
  - `struct ReviewListView: View` — `init(repository: (any TransactionRepository)? = nil, onSelect: @escaping (UUID) -> Void)`.
  - `struct ReviewDetailView: View` — `init(draftID:repository:initialType:initialNominal:initialDescription:initialParticipants:)`.
  - `struct ReviewContactPickerSheet: View` — `init(isMultiSelect:totalAmount:initialSelected:onSelectSingle:onSelectMultiple:)`.
  - `struct ReviewCardView: View` — `init(item: ReviewItemUIModel)`.
  - `struct SmartContactCardView: View` — `init(participant: ReviewParticipantUIModel, onConfirmTypo:onRejectTypo:onOpenPicker:)`.

- [ ] **Step 1: Park the legacy screen and move the Draft files**

```bash
mkdir -p UcapHutang/Features/Review/Legacy UcapHutang/Features/Review/Views UcapHutang/Features/Review/ViewModels UcapHutang/Features/Review/Components UcapHutang/Features/Review/Models
git mv UcapHutang/Features/Review/ReviewDraftView.swift UcapHutang/Features/Review/Legacy/ReviewDraftView.swift
git mv UcapHutang/Features/Review/ReviewDraftViewModel.swift UcapHutang/Features/Review/Legacy/ReviewDraftViewModel.swift
git mv UcapHutang/Features/Review/ContactPickerSheet.swift UcapHutang/Features/Review/Legacy/ContactPickerSheet.swift
git mv UcapHutang/Features/Draft/Models/DraftUIModels.swift UcapHutang/Features/Review/Models/ReviewUIModels.swift
git mv UcapHutang/Features/Draft/ViewModels/DraftListViewModel.swift UcapHutang/Features/Review/ViewModels/ReviewListViewModel.swift
git mv UcapHutang/Features/Draft/ViewModels/DraftReviewViewModel.swift UcapHutang/Features/Review/ViewModels/ReviewDetailViewModel.swift
git mv UcapHutang/Features/Draft/ViewModels/DraftContactPickerViewModel.swift UcapHutang/Features/Review/ViewModels/ReviewContactPickerViewModel.swift
git mv UcapHutang/Features/Draft/DraftListView.swift UcapHutang/Features/Review/Views/ReviewListView.swift
git mv UcapHutang/Features/Draft/Views/DraftReviewView.swift UcapHutang/Features/Review/Views/ReviewDetailView.swift
git mv UcapHutang/Features/Draft/Views/DraftContactPickerSheet.swift UcapHutang/Features/Review/Views/ReviewContactPickerSheet.swift
git mv UcapHutang/Features/Draft/Views/Components/DraftCardView.swift UcapHutang/Features/Review/Components/ReviewCardView.swift
git mv UcapHutang/Features/Draft/Views/Components/SmartContactCardView.swift UcapHutang/Features/Review/Components/SmartContactCardView.swift
git mv UcapHutang/Features/Draft/Views/Components/SplitParticipantRow.swift UcapHutang/Features/Review/Components/SplitParticipantRow.swift
git mv UcapHutang/Features/Components.swift UcapHutang/Core/DesignSystem/FilteredCardListView.swift
find UcapHutang/Features/Draft -type d -empty -delete
test ! -e UcapHutang/Features/Draft && echo "Draft folder removed"
```

Expected last line: `Draft folder removed`.

- [ ] **Step 2: Replace `ReviewUIModels.swift`**

Full content of `UcapHutang/Features/Review/Models/ReviewUIModels.swift`:

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

// MARK: - Smart Contact Linking State
enum ContactLinkState: Equatable, Sendable {
    /// Terhubung langsung tanpa keraguan
    case autoLinked(matchedContactName: String)
    /// AI mendeteksi kemiripan nama / potensi typo
    case typoSuggestion(suggestedName: String, originalName: String)
    /// Belum terhubung ke kontak manapun
    case unlinked

    var statusText: String {
        switch self {
        case .autoLinked:
            return "Terhubung otomatis ke kontak"
        case .typoSuggestion(let suggestedName, _):
            return "Mirip kontak \"\(suggestedName)\" — Typo?"
        case .unlinked:
            return "Belum terhubung"
        }
    }
}

// MARK: - Review Item UI Model
struct ReviewItemUIModel: Identifiable, Equatable, Sendable {
    let id: UUID
    var type: TransactionType
    var prefix: String // "ke" atau "dari"
    var personName: String // "Dito", "Krisna", "3 Orang"
    var avatarInitials: [String] // ["E", "C", "D"] untuk split bill
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

// MARK: - Review Participant UI Model
struct ReviewParticipantUIModel: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var shareAmount: Int64
    var linkState: ContactLinkState
    var contactIdentifier: String?
    var phoneNumber: String?

    init(
        id: UUID = UUID(),
        name: String,
        shareAmount: Int64 = 0,
        linkState: ContactLinkState = .unlinked,
        contactIdentifier: String? = nil,
        phoneNumber: String? = nil
    ) {
        self.id = id
        self.name = name
        self.shareAmount = shareAmount
        self.linkState = linkState
        self.contactIdentifier = contactIdentifier
        self.phoneNumber = phoneNumber
    }
}

// MARK: - Contact Picker UI Models
struct ContactUIModel: Identifiable, Equatable, Sendable {
    let id: String
    var fullName: String
    var phoneNumber: String?
    var isFromHistory: Bool

    init(
        id: String = UUID().uuidString,
        fullName: String,
        phoneNumber: String? = nil,
        isFromHistory: Bool = false
    ) {
        self.id = id
        self.fullName = fullName
        self.phoneNumber = phoneNumber
        self.isFromHistory = isFromHistory
    }
}

struct SelectedContactUIModel: Identifiable, Equatable, Sendable {
    let id: String
    var name: String
    var amount: Int64
    var isCustomAmount: Bool

    init(
        id: String,
        name: String,
        amount: Int64 = 0,
        isCustomAmount: Bool = false
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.isCustomAmount = isCustomAmount
    }
}

// MARK: - Mock / Preview Data (removed from production code in P3)
enum ReviewMockData {
    static let sampleDrafts: [ReviewItemUIModel] = [
        ReviewItemUIModel(
            type: .piutang,
            prefix: "ke",
            personName: "Dito",
            description: "“pinjam buat makan siang”",
            relativeTime: "5 menit lalu",
            amount: 15_000
        ),
        ReviewItemUIModel(
            type: .hutang,
            prefix: "dari",
            personName: "Krisna",
            description: "“buat bayar kost”",
            relativeTime: "5 menit lalu",
            amount: 500_000
        ),
        ReviewItemUIModel(
            type: .splitBill,
            prefix: "ke",
            personName: "3 Orang",
            avatarInitials: ["E", "C", "D"],
            description: "“makan malam, bagi rata”",
            relativeTime: "5 menit lalu",
            amount: 300_000
        )
    ]

    static let sampleHistoryContacts: [ContactUIModel] = [
        ContactUIModel(fullName: "Budi Santoso", phoneNumber: "+62 81234123123", isFromHistory: true),
        ContactUIModel(fullName: "Andito Rizkika", phoneNumber: "+62 81234123123", isFromHistory: true)
    ]

    static let sampleDeviceContacts: [ContactUIModel] = [
        ContactUIModel(fullName: "Budi Santoso", phoneNumber: "+62 81234123123", isFromHistory: false),
        ContactUIModel(fullName: "Budi Santoso", phoneNumber: "+62 81234123123", isFromHistory: false),
        ContactUIModel(fullName: "Andito Rizkika", phoneNumber: "+62 81234123123", isFromHistory: false)
    ]
}
```

- [ ] **Step 3: Replace `ReviewListViewModel.swift`**

Full content of `UcapHutang/Features/Review/ViewModels/ReviewListViewModel.swift`:

```swift
import Foundation
import Observation

@Observable
final class ReviewListViewModel {
    private(set) var drafts: [ReviewItemUIModel] = []
    var selectedFilter: ReviewFilterType = .all
    var errorMessage: String?

    private let repository: (any TransactionRepository)?

    init(repository: (any TransactionRepository)? = nil, previewDrafts: [ReviewItemUIModel]? = nil) {
        self.repository = repository
        if let previewDrafts {
            self.drafts = previewDrafts
        } else if repository == nil {
            // Default mock data untuk slicing & preview
            self.drafts = ReviewMockData.sampleDrafts
        }
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
        guard let repository else {
            // Jika dalam mode standalone/slicing preview tanpa repo
            if drafts.isEmpty {
                drafts = ReviewMockData.sampleDrafts
            }
            return
        }

        do {
            let entityDrafts = try await repository.draftsNeedingReview()
            self.drafts = entityDrafts.map { entity in
                let prefix: String
                let personName: String
                var avatarInitials: [String] = []

                if entity.flow == .splitBill || entity.type == .splitBill {
                    prefix = "ke"
                    personName = "\(max(1, entity.participants.count)) Orang"
                    avatarInitials = entity.participants.prefix(3).map { participant in
                        let trimmed = participant.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        return String(trimmed.prefix(1)).uppercased()
                    }
                    if avatarInitials.isEmpty {
                        avatarInitials = ["E", "C", "D"]
                    }
                } else if entity.type == .piutang {
                    prefix = "ke"
                    personName = entity.participants.first?.name ?? "Teman"
                } else {
                    prefix = "dari"
                    personName = entity.participants.first?.name ?? "Teman"
                }

                let desc = entity.notes?.isEmpty == false ? "“\(entity.notes!)”" : "“\(entity.title)”"

                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .full
                formatter.locale = Locale(identifier: "id_ID")
                let relTime = formatter.localizedString(for: entity.createdAt, relativeTo: Date())

                return ReviewItemUIModel(
                    id: entity.id,
                    type: entity.type,
                    prefix: prefix,
                    personName: personName,
                    avatarInitials: avatarInitials,
                    description: desc,
                    relativeTime: relTime.isEmpty ? "5 menit lalu" : relTime,
                    amount: entity.totalAmount,
                    date: entity.transactionDate
                )
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func deleteDraft(id: UUID) async {
        if let repository {
            try? await repository.discardDraft(id: id)
        }
        drafts.removeAll { $0.id == id }
    }
}
```

- [ ] **Step 4: Replace `ReviewDetailViewModel.swift`**

Full content of `UcapHutang/Features/Review/ViewModels/ReviewDetailViewModel.swift`:

```swift
import Foundation
import Observation

@Observable
final class ReviewDetailViewModel {
    let draftID: UUID
    var timeText: String = "Hari ini, 12:41"
    var transactionDate: Date = Date()
    var nominal: Int64 = 150_000
    var description: String = "Pinjam buat makan siang"
    var transactionType: TransactionType = .hutang
    var participants: [ReviewParticipantUIModel] = []
    var isSaving: Bool = false
    var didFinish: Bool = false
    var errorMessage: String?
    var showDeleteConfirmation: Bool = false
    var activeContactPickerParticipantID: UUID?

    private let repository: (any TransactionRepository)?

    init(
        draftID: UUID = UUID(),
        repository: (any TransactionRepository)? = nil,
        initialType: TransactionType = .hutang,
        initialNominal: Int64 = 150_000,
        initialDescription: String = "Pinjam buat makan siang",
        initialParticipants: [ReviewParticipantUIModel]? = nil
    ) {
        self.draftID = draftID
        self.repository = repository
        self.transactionType = initialType
        self.nominal = initialNominal
        self.description = initialDescription

        if let initialParticipants {
            self.participants = initialParticipants
        } else {
            // Default mock data untuk slicing & preview: 1 orang "Dito" terhubung otomatis
            self.participants = [
                ReviewParticipantUIModel(
                    name: "Dito",
                    shareAmount: initialNominal,
                    linkState: .autoLinked(matchedContactName: "Andito Rizkika"),
                    contactIdentifier: "1",
                    phoneNumber: "+62 81234123123"
                )
            ]
        }
    }

    var formattedNominal: String {
        nominal.rupiahFormatted
    }

    func setTransactionType(_ type: TransactionType) {
        self.transactionType = type
    }

    func confirmTypo(for participantID: UUID) {
        guard let index = participants.firstIndex(where: { $0.id == participantID }) else { return }
        if case .typoSuggestion(let suggestedName, _) = participants[index].linkState {
            participants[index].name = suggestedName
            participants[index].linkState = .autoLinked(matchedContactName: suggestedName)
        }
    }

    func rejectTypo(for participantID: UUID) {
        guard let index = participants.firstIndex(where: { $0.id == participantID }) else { return }
        // Biarkan nama asli, set ke unlinked, dan buka modal picker
        participants[index].linkState = .unlinked
        activeContactPickerParticipantID = participantID
    }

    func openContactPicker(for participantID: UUID) {
        activeContactPickerParticipantID = participantID
    }

    func addParticipant() {
        let newParticipant = ReviewParticipantUIModel(
            name: "Orang Baru",
            shareAmount: 0,
            linkState: .unlinked
        )
        participants.append(newParticipant)
        recalculateEqualSplit()
    }

    func removeParticipant(id: UUID) {
        participants.removeAll { $0.id == id }
        recalculateEqualSplit()
    }

    func updateParticipantContact(id: UUID, contact: ContactUIModel) {
        guard let index = participants.firstIndex(where: { $0.id == id }) else { return }
        participants[index].name = contact.fullName
        participants[index].phoneNumber = contact.phoneNumber
        participants[index].contactIdentifier = contact.id
        participants[index].linkState = .autoLinked(matchedContactName: contact.fullName)
    }

    private func recalculateEqualSplit() {
        guard !participants.isEmpty, nominal > 0 else { return }
        let share = nominal / Int64(participants.count)
        for i in participants.indices {
            participants[i].shareAmount = share
        }
    }

    func saveDraft() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        if let repository {
            do {
                if var loaded = try await repository.draft(id: draftID) {
                    loaded.type = transactionType
                    loaded.totalAmount = nominal
                    loaded.title = description
                    loaded.transactionDate = transactionDate
                    loaded.status = .confirmed
                    try await repository.confirmDraft(loaded)
                }
            } catch {
                self.errorMessage = error.localizedDescription
                return
            }
        }

        didFinish = true
    }

    func deleteDraft() async {
        if let repository {
            try? await repository.discardDraft(id: draftID)
        }
        didFinish = true
    }
}
```

- [ ] **Step 5: Replace `ReviewContactPickerViewModel.swift`**

Full content of `UcapHutang/Features/Review/ViewModels/ReviewContactPickerViewModel.swift`:

```swift
import Foundation
import Observation

@Observable
final class ReviewContactPickerViewModel {
    var searchQuery: String = ""
    let isMultiSelect: Bool
    var totalAmount: Int64
    var selectedContacts: [SelectedContactUIModel] = []
    private(set) var recentContacts: [ContactUIModel] = []
    private(set) var deviceContacts: [ContactUIModel] = []

    init(
        isMultiSelect: Bool = false,
        totalAmount: Int64 = 300_000,
        initialSelected: [SelectedContactUIModel] = [],
        recentContacts: [ContactUIModel] = ReviewMockData.sampleHistoryContacts,
        deviceContacts: [ContactUIModel] = ReviewMockData.sampleDeviceContacts
    ) {
        self.isMultiSelect = isMultiSelect
        self.totalAmount = totalAmount
        self.recentContacts = recentContacts
        self.deviceContacts = deviceContacts

        if !initialSelected.isEmpty {
            self.selectedContacts = initialSelected
        } else if isMultiSelect {
            // Mock sample multi-selection for preview if empty
            self.selectedContacts = [
                SelectedContactUIModel(id: "1", name: "Orang A", amount: 100_000),
                SelectedContactUIModel(id: "2", name: "Orang B", amount: 100_000),
                SelectedContactUIModel(id: "3", name: "Orang C", amount: 100_000)
            ]
        }
    }

    var filteredRecentContacts: [ContactUIModel] {
        guard !searchQuery.isEmpty else { return recentContacts }
        return recentContacts.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchQuery) ||
            ($0.phoneNumber?.localizedCaseInsensitiveContains(searchQuery) ?? false)
        }
    }

    var filteredDeviceContacts: [ContactUIModel] {
        guard !searchQuery.isEmpty else { return deviceContacts }
        return deviceContacts.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchQuery) ||
            ($0.phoneNumber?.localizedCaseInsensitiveContains(searchQuery) ?? false)
        }
    }

    var totalAllocatedAmount: Int64 {
        selectedContacts.reduce(0) { $0 + $1.amount }
    }

    var hasNoResults: Bool {
        !searchQuery.isEmpty && filteredRecentContacts.isEmpty && filteredDeviceContacts.isEmpty
    }

    func isSelected(contactID: String) -> Bool {
        selectedContacts.contains { $0.id == contactID }
    }

    func toggleSelection(for contact: ContactUIModel) {
        if isMultiSelect {
            if let index = selectedContacts.firstIndex(where: { $0.id == contact.id }) {
                selectedContacts.remove(at: index)
            } else {
                selectedContacts.append(SelectedContactUIModel(id: contact.id, name: contact.fullName, amount: 0))
            }
            recalculateEqualSplit()
        } else {
            selectedContacts = [SelectedContactUIModel(id: contact.id, name: contact.fullName, amount: totalAmount)]
        }
    }

    func updateCustomAmount(for contactID: String, amount: Int64) {
        guard let index = selectedContacts.firstIndex(where: { $0.id == contactID }) else { return }
        selectedContacts[index].amount = amount
        selectedContacts[index].isCustomAmount = true
    }

    func createNewContact(name: String) -> ContactUIModel {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let newContact = ContactUIModel(id: UUID().uuidString, fullName: clean, phoneNumber: nil, isFromHistory: true)
        recentContacts.insert(newContact, at: 0)
        toggleSelection(for: newContact)
        searchQuery = ""
        return newContact
    }

    private func recalculateEqualSplit() {
        guard !selectedContacts.isEmpty, totalAmount > 0 else { return }
        let uncustomized = selectedContacts.filter { !$0.isCustomAmount }
        let customTotal = selectedContacts.filter { $0.isCustomAmount }.reduce(Int64(0)) { $0 + $1.amount }
        let remaining = max(0, totalAmount - customTotal)

        guard !uncustomized.isEmpty else { return }
        let share = remaining / Int64(uncustomized.count)

        for i in selectedContacts.indices where !selectedContacts[i].isCustomAmount {
            selectedContacts[i].amount = share
        }
    }
}
```

- [ ] **Step 6: Replace `ReviewListView.swift`**

Full content of `UcapHutang/Features/Review/Views/ReviewListView.swift`:

```swift
import SwiftUI

struct ReviewListView: View {
    @State private var viewModel: ReviewListViewModel
    let onSelect: (UUID) -> Void

    init(repository: (any TransactionRepository)? = nil, onSelect: @escaping (UUID) -> Void) {
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
    ReviewListView(repository: nil) { _ in }
}
```

- [ ] **Step 7: Replace `ReviewDetailView.swift`**

Full content of `UcapHutang/Features/Review/Views/ReviewDetailView.swift`:

```swift
import SwiftUI

struct ReviewDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ReviewDetailViewModel
    @State private var isShowingDatePicker = false

    init(
        draftID: UUID = UUID(),
        repository: (any TransactionRepository)? = nil,
        initialType: TransactionType = .hutang,
        initialNominal: Int64 = 150_000,
        initialDescription: String = "Pinjam buat makan siang",
        initialParticipants: [ReviewParticipantUIModel]? = nil
    ) {
        _viewModel = State(initialValue: ReviewDetailViewModel(
            draftID: draftID,
            repository: repository,
            initialType: initialType,
            initialNominal: initialNominal,
            initialDescription: initialDescription,
            initialParticipants: initialParticipants
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // MARK: - Waktu
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Waktu")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)

                        Button {
                            isShowingDatePicker.toggle()
                        } label: {
                            HStack {
                                Text(viewModel.timeText)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(AppColors.textPrimary)
                                Spacer()
                                Image(systemName: "calendar")
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)

                        if isShowingDatePicker {
                            DatePicker(
                                "",
                                selection: $viewModel.transactionDate,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.graphical)
                            .onChange(of: viewModel.transactionDate) { _, newDate in
                                let formatter = DateFormatter()
                                formatter.locale = Locale(identifier: "id_ID")
                                formatter.dateFormat = "d MMM, HH:mm"
                                viewModel.timeText = "Hari ini, " + formatter.string(from: newDate)
                            }
                        }
                    }

                    // MARK: - Nominal
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nominal")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)

                        Text(viewModel.formattedNominal)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                    }

                    // MARK: - Deskripsi
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Deskripsi")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)

                        TextField("Deskripsi transaksi", text: $viewModel.description)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                    }

                    // MARK: - Jenis (Segmented Control)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Jenis")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)

                        Picker("Jenis", selection: Binding(
                            get: { viewModel.transactionType },
                            set: { viewModel.setTransactionType($0) }
                        )) {
                            Text("Utang").tag(TransactionType.hutang)
                            Text("Piutang").tag(TransactionType.piutang)
                        }
                        .pickerStyle(.segmented)
                    }

                    // MARK: - Orang (Smart Contact Cards)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Orang")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)

                        ForEach(viewModel.participants) { participant in
                            SmartContactCardView(
                                participant: participant,
                                onConfirmTypo: {
                                    viewModel.confirmTypo(for: participant.id)
                                },
                                onRejectTypo: {
                                    viewModel.rejectTypo(for: participant.id)
                                },
                                onOpenPicker: {
                                    viewModel.openContactPicker(for: participant.id)
                                }
                            )
                        }

                        // Tombol Tambah Orang (Outlined / Dotted)
                        Button {
                            viewModel.addParticipant()
                        } label: {
                            HStack {
                                Spacer()
                                Text("+ Tambah orang")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppColors.textSecondary)
                                Spacer()
                            }
                            .frame(minHeight: 44)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                    .foregroundStyle(Color.secondary.opacity(0.4))
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 40)

                    // MARK: - Action Buttons (Bottom)
                    VStack(spacing: 12) {
                        Button {
                            Task { await viewModel.saveDraft() }
                        } label: {
                            Text("Simpan Catatan")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(Color.primary)
                                .foregroundStyle(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        Button {
                            viewModel.showDeleteConfirmation = true
                        } label: {
                            Text("Hapus catatan ini")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppColors.textSecondary)
                                .frame(maxWidth: .infinity, minHeight: 36)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Review Catatan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                }
            }
            .onChange(of: viewModel.didFinish) { _, finished in
                if finished {
                    dismiss()
                }
            }
            .sheet(item: Binding<IdentifiableUUID?>(
                get: { viewModel.activeContactPickerParticipantID.map { IdentifiableUUID($0) } },
                set: { viewModel.activeContactPickerParticipantID = $0?.id }
            )) { identifiable in
                ReviewContactPickerSheet(
                    isMultiSelect: false,
                    onSelectSingle: { selected in
                        viewModel.updateParticipantContact(id: identifiable.id, contact: selected)
                    }
                )
            }
            .confirmationDialog("Hapus catatan ini?", isPresented: $viewModel.showDeleteConfirmation, titleVisibility: .visible) {
                Button("Hapus Catatan", role: .destructive) {
                    Task { await viewModel.deleteDraft() }
                }
                Button("Batal", role: .cancel) {}
            } message: {
                Text("Draf transaksi ini akan dihapus permanen.")
            }
        }
    }
}

#Preview("Review - Connected") {
    ReviewDetailView(
        initialType: .hutang,
        initialNominal: 150_000,
        initialDescription: "Pinjam buat makan siang",
        initialParticipants: [
            ReviewParticipantUIModel(
                name: "Dito",
                linkState: .autoLinked(matchedContactName: "Andito Rizkika")
            )
        ]
    )
}

#Preview("Review - Typo Suggestion") {
    ReviewDetailView(
        initialType: .hutang,
        initialNominal: 150_000,
        initialDescription: "Pinjam buat makan siang",
        initialParticipants: [
            ReviewParticipantUIModel(
                name: "Dito Rizkaka",
                linkState: .typoSuggestion(suggestedName: "Dito Rizkika", originalName: "Dito Rizkaka")
            )
        ]
    )
}

#Preview("Review - Unlinked") {
    ReviewDetailView(
        initialType: .hutang,
        initialNominal: 150_000,
        initialDescription: "Pinjam buat makan siang",
        initialParticipants: [
            ReviewParticipantUIModel(
                name: "Dito Rizkaka",
                linkState: .unlinked
            )
        ]
    )
}
```

- [ ] **Step 8: Replace `ReviewContactPickerSheet.swift`**

Full content of `UcapHutang/Features/Review/Views/ReviewContactPickerSheet.swift`:

```swift
import SwiftUI

struct ReviewContactPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ReviewContactPickerViewModel

    var onSelectSingle: ((ContactUIModel) -> Void)?
    var onSelectMultiple: (([SelectedContactUIModel]) -> Void)?

    init(
        isMultiSelect: Bool = false,
        totalAmount: Int64 = 300_000,
        initialSelected: [SelectedContactUIModel] = [],
        onSelectSingle: ((ContactUIModel) -> Void)? = nil,
        onSelectMultiple: (([SelectedContactUIModel]) -> Void)? = nil
    ) {
        _viewModel = State(initialValue: ReviewContactPickerViewModel(
            isMultiSelect: isMultiSelect,
            totalAmount: totalAmount,
            initialSelected: initialSelected
        ))
        self.onSelectSingle = onSelectSingle
        self.onSelectMultiple = onSelectMultiple
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    // MARK: - Section Terpilih (Khusus Multi-select / Split)
                    if viewModel.isMultiSelect && !viewModel.selectedContacts.isEmpty {
                        Section("Terpilih") {
                            ForEach(viewModel.selectedContacts) { contact in
                                SplitParticipantRow(contact: contact) { newAmount in
                                    viewModel.updateCustomAmount(for: contact.id, amount: newAmount)
                                }
                            }

                            HStack {
                                Text("Total")
                                    .font(.body.weight(.bold))
                                    .foregroundStyle(AppColors.textPrimary)

                                Spacer()

                                Text(viewModel.totalAllocatedAmount.rupiahFormatted)
                                    .font(.body.weight(.bold))
                                    .foregroundStyle(AppColors.textPrimary)
                            }
                            .padding(.top, 4)
                        }
                    }

                    // MARK: - Empty Search State / Add New Contact
                    if viewModel.hasNoResults {
                        Section {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Tidak menemukan kontak?")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.textSecondary)

                                Button {
                                    let newContact = viewModel.createNewContact(name: viewModel.searchQuery)
                                    if !viewModel.isMultiSelect {
                                        onSelectSingle?(newContact)
                                        dismiss()
                                    }
                                } label: {
                                    Text("Buat kontak baru \"\(viewModel.searchQuery)\"")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppColors.accent)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 8)
                        }
                    } else {
                        // MARK: - Section Kontak yang Pernah Dicatat
                        if !viewModel.filteredRecentContacts.isEmpty {
                            Section("Kontak yang pernah di catat") {
                                ForEach(viewModel.filteredRecentContacts) { contact in
                                    contactRow(contact: contact)
                                }
                            }
                        }

                        // MARK: - Section Kontak yang Kamu Simpan
                        if !viewModel.filteredDeviceContacts.isEmpty {
                            Section("Kontak yang kamu simpan") {
                                ForEach(viewModel.filteredDeviceContacts) { contact in
                                    contactRow(contact: contact)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Hubungkan ke kontak")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        if viewModel.isMultiSelect {
                            onSelectMultiple?(viewModel.selectedContacts)
                        } else if let first = viewModel.selectedContacts.first {
                            let match = ContactUIModel(id: first.id, fullName: first.name)
                            onSelectSingle?(match)
                        }
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(AppColors.accent)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func contactRow(contact: ContactUIModel) -> some View {
        let selected = viewModel.isSelected(contactID: contact.id)

        Button {
            viewModel.toggleSelection(for: contact)
            if !viewModel.isMultiSelect {
                onSelectSingle?(contact)
                dismiss()
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.fullName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(AppColors.textPrimary)

                    if let phone = contact.phoneNumber {
                        Text(phone)
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? AppColors.textPrimary : Color.secondary.opacity(0.4))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Single Select") {
    ReviewContactPickerSheet(isMultiSelect: false)
}

#Preview("Multi Select") {
    ReviewContactPickerSheet(isMultiSelect: true, totalAmount: 300_000)
}
```

- [ ] **Step 9: Replace `ReviewCardView.swift` and `SmartContactCardView.swift`**

Full content of `UcapHutang/Features/Review/Components/ReviewCardView.swift`:

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
        ForEach(ReviewMockData.sampleDrafts) { draft in
            ReviewCardView(item: draft)
        }
    }
    .padding()
    .background(Color(.systemBackground))
}
```

Full content of `UcapHutang/Features/Review/Components/SmartContactCardView.swift`:

```swift
import SwiftUI

struct SmartContactCardView: View {
    let participant: ReviewParticipantUIModel
    var onConfirmTypo: (() -> Void)?
    var onRejectTypo: (() -> Void)?
    var onOpenPicker: (() -> Void)?

    init(
        participant: ReviewParticipantUIModel,
        onConfirmTypo: (() -> Void)? = nil,
        onRejectTypo: (() -> Void)? = nil,
        onOpenPicker: (() -> Void)? = nil
    ) {
        self.participant = participant
        self.onConfirmTypo = onConfirmTypo
        self.onRejectTypo = onRejectTypo
        self.onOpenPicker = onOpenPicker
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch participant.linkState {
            case .autoLinked:
                // State A: Terhubung otomatis
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(participant.name)
                            .font(.body.weight(.medium))
                            .foregroundStyle(AppColors.textPrimary)

                        Text("Terhubung otomatis ke kontak")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer()

                    Button {
                        onOpenPicker?()
                    } label: {
                        Text("Bukan dia?")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }

            case .typoSuggestion(let suggestedName, _):
                // State B: Nama Orang Typo
                VStack(alignment: .leading, spacing: 8) {
                    Text(participant.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Mirip kontak \"\(suggestedName)\" — Typo?")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)

                    HStack(spacing: 8) {
                        Button {
                            onConfirmTypo?()
                        } label: {
                            Text("Ya, hubungkan")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.secondarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)

                        Button {
                            onRejectTypo?()
                        } label: {
                            Text("Bukan, ganti")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.secondarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }

            case .unlinked:
                // State C: Orangnya belum terhubung
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(participant.name)
                            .font(.body.weight(.medium))
                            .foregroundStyle(AppColors.textPrimary)

                        Text("Belum terhubung")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer()

                    Button {
                        onOpenPicker?()
                    } label: {
                        Text("Hubungkan")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.secondarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview("3 States") {
    VStack(spacing: 16) {
        // State A
        SmartContactCardView(
            participant: ReviewParticipantUIModel(
                name: "Dito",
                linkState: .autoLinked(matchedContactName: "Andito Rizkika")
            )
        )

        // State B
        SmartContactCardView(
            participant: ReviewParticipantUIModel(
                name: "Dito Rizkaka",
                linkState: .typoSuggestion(suggestedName: "Dito Rizkika", originalName: "Dito Rizkaka")
            )
        )

        // State C
        SmartContactCardView(
            participant: ReviewParticipantUIModel(
                name: "Dito Rizkaka",
                linkState: .unlinked
            )
        )
    }
    .padding()
}
```

- [ ] **Step 10: Point `RootTabView` at the renamed views**

In `UcapHutang/App/RootTabView.swift`:

- Replace `DraftListView(repository: container.repository) { draftID in` with `ReviewListView(repository: container.repository) { draftID in`
- Replace `DraftReviewView(draftID: item.id, repository: container.repository)` with `ReviewDetailView(draftID: item.id, repository: container.repository)`

Change nothing else in that file (Task 5 rewrites it).

- [ ] **Step 11: Check no old names remain**

```bash
grep -rn --include='*.swift' -E "\bDraft(ListView|ListViewModel|ReviewView|ReviewViewModel|CardView|ContactPickerSheet|ContactPickerViewModel|ItemUIModel|ParticipantUIModel|FilterType|MockData)\b|ViewModelProtocol" UcapHutang UcapHutangTests
```

Expected: **no output**.

- [ ] **Step 12: Build and test**

Run the full test command. Expected: `Executed 21 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 13: Commit**

```bash
git add UcapHutang/Features/Review UcapHutang/Core/DesignSystem/FilteredCardListView.swift UcapHutang/App/RootTabView.swift
git commit -m "refactor: merge Draft feature into Review with Review* names and @Observable"
```

---

### Task 4: Catat feature + SpeechRecognizer `@Observable`

**Files:**
- Move: `UcapHutang/Features/Catat/CatatView.swift` → `UcapHutang/Features/Catat/Views/CatatView.swift`
- Move (content unchanged): `UcapHutang/Features/Catat/CatatFlowChooserView.swift` → `UcapHutang/Features/Catat/Views/CatatFlowChooserView.swift`
- Move + replace: `UcapHutang/Features/Catat/CatatViewModel.swift` → `UcapHutang/Features/Catat/ViewModels/CatatViewModel.swift`
- Replace: `UcapHutang/Features/Catat/Views/CatatView.swift`
- Replace: `UcapHutang/Services/Speech/SpeechRecognizer.swift`

**Interfaces:**
- Consumes: `AppContainer` (still `ObservableObject` until Task 5 — only its `let` properties are read), `DraftExtractionRequest`, `CaptureFlow`, `ReviewDraftView` (legacy, `init(draftID:repository:)`).
- Produces:
  - `@Observable public final class SpeechRecognizer` — same public API: `state`, `isRecording`, `errorMessage`, `audioLevel`, `startRecording(onTranscript:)`, `finishRecording() async -> String`, `cancelRecording()`.
  - `@Observable final class CatatViewModel` — `init(flow:container:)`, `flow`, `createdDraftID`, `container`, `speechRecognizer`, `liveTranscript`, `isProcessing`, `errorMessage`, `isStartingRecording`, `stageHeadline`, `handleMicTap()`, `restartRecording()`, `handleSpeechStateChange(_:)`, `cancel()`. (`micButtonGradient` is deleted — it had no callers.)

- [ ] **Step 1: Move files**

```bash
mkdir -p UcapHutang/Features/Catat/Views UcapHutang/Features/Catat/ViewModels
git mv UcapHutang/Features/Catat/CatatView.swift UcapHutang/Features/Catat/Views/CatatView.swift
git mv UcapHutang/Features/Catat/CatatFlowChooserView.swift UcapHutang/Features/Catat/Views/CatatFlowChooserView.swift
git mv UcapHutang/Features/Catat/CatatViewModel.swift UcapHutang/Features/Catat/ViewModels/CatatViewModel.swift
```

- [ ] **Step 2: Replace `SpeechRecognizer.swift`**

Full content of `UcapHutang/Services/Speech/SpeechRecognizer.swift`:

```swift
import Foundation
import Speech
import AVFoundation
import Observation

public enum SpeechRecognizerState: Equatable, Sendable {
    case idle
    case listening
    case finalizing
    case failed(String)
}

@Observable
public final class SpeechRecognizer {
    public var state: SpeechRecognizerState = .idle
    public var isRecording = false
    public var errorMessage: String?
    public var audioLevel: Float = 0.0

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "id-ID")) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @ObservationIgnored private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    @ObservationIgnored private var hasInstalledInputTap = false
    @ObservationIgnored private var activeTranscript: String = ""
    @ObservationIgnored private var transcriptContinuation: CheckedContinuation<String, Never>?

    public init() {}

    public func startRecording(onTranscript: @escaping @MainActor (String) -> Void) {
        errorMessage = nil
        activeTranscript = ""

        AVAudioApplication.requestRecordPermission { [weak self] microphoneGranted in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard microphoneGranted else {
                    self.setError("Izin mikrofon ditolak. Buka Settings untuk mengaktifkan.")
                    return
                }
                self.requestSpeechAuthorization(onTranscript: onTranscript)
            }
        }
    }

    private func requestSpeechAuthorization(onTranscript: @escaping @MainActor (String) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch authStatus {
                case .authorized:
                    self.performStartRecording(onTranscript: onTranscript)
                case .denied:
                    self.setError("Izin Speech Recognition ditolak. Buka Settings untuk mengaktifkan.")
                case .restricted:
                    self.setError("Speech Recognition dibatasi pada perangkat ini.")
                case .notDetermined:
                    self.setError("Izin Speech Recognition belum ditentukan.")
                @unknown default:
                    self.setError("Status otorisasi Speech Recognition tidak dikenal.")
                }
            }
        }
    }

    private func performStartRecording(onTranscript: @escaping @MainActor (String) -> Void) {
        if recognitionTask != nil {
            cancelRecording()
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            setError("Gagal menginisialisasi AVAudioSession: \(error.localizedDescription)")
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation

        if #available(iOS 16.0, *) {
            request.addsPunctuation = true
        }

        let baseVocabulary = [
            "nalangin", "nalagin", "talangin", "bayarin", "nombokin", "tombokin",
            "ngutang", "piutang", "hutang", "pinjem", "minjem", "minjemin",
            "split bill", "splitbill", "patungan", "bagi rata", "urunan",
            "gacoan", "ramen", "kopi", "bensin", "konser", "tiket",
            "ribu", "juta", "jt", "rb", "k"
        ]
        request.contextualStrings = Array(baseVocabulary.prefix(100))
        self.recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result = result {
                let text = result.bestTranscription.formattedString
                self.activeTranscript = text
                Task { @MainActor in
                    onTranscript(text)
                }

                if result.isFinal {
                    self.finishTaskAndCleanup(finalTranscript: text)
                }
            }

            if let error = error {
                if self.state == .finalizing {
                    self.finishTaskAndCleanup(finalTranscript: self.activeTranscript)
                } else if self.isRecording {
                    self.setError("Speech recognition error: \(error.localizedDescription)")
                    self.finishTaskAndCleanup(finalTranscript: self.activeTranscript)
                }
            }
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self else { return }
            self.recognitionRequest?.append(buffer)
            self.processAudioLevel(from: buffer)
        }
        hasInstalledInputTap = true

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            state = .listening
        } catch {
            removeInputTap()
            setError("Gagal memulai AudioEngine: \(error.localizedDescription)")
        }
    }

    public func finishRecording() async -> String {
        guard isRecording || state == .listening else {
            return activeTranscript
        }
        state = .finalizing
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
        }
        removeInputTap()

        return await withCheckedContinuation { continuation in
            self.transcriptContinuation = continuation

            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 750_000_000)
                guard let self, self.state == .finalizing else { return }
                self.finishTaskAndCleanup(finalTranscript: self.activeTranscript)
            }
        }
    }

    public func cancelRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
        }
        removeInputTap()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false
        state = .idle
        audioLevel = 0.0

        if let cont = transcriptContinuation {
            transcriptContinuation = nil
            cont.resume(returning: activeTranscript)
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func finishTaskAndCleanup(finalTranscript: String) {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false
        state = .idle
        audioLevel = 0.0

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        if let cont = transcriptContinuation {
            transcriptContinuation = nil
            cont.resume(returning: finalTranscript)
        }
    }

    private func processAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let channelDataArray = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))

        var sum: Float = 0.0
        for sample in channelDataArray {
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(buffer.frameLength))
        let db = 20 * log10(max(rms, 0.0001))

        let minDb: Float = -50.0
        let maxDb: Float = -5.0
        let rawNormalized = max(0.0, min(1.0, (db - minDb) / (maxDb - minDb)))

        Task { @MainActor [weak self] in
            guard let self, self.isRecording else { return }
            let smoothed = (self.audioLevel * 0.4) + (rawNormalized * 0.6)
            self.audioLevel = smoothed
        }
    }

    private func setError(_ message: String) {
        errorMessage = message
        state = .failed(message)
        isRecording = false
    }

    private func removeInputTap() {
        guard hasInstalledInputTap else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        hasInstalledInputTap = false
    }
}
```

Only these lines differ from the previous file: `import Combine` → `import Observation`; `: ObservableObject` removed and `@Observable` added; `@Published` removed from the four public properties; `@ObservationIgnored` added to the five internal `var`s. All logic is identical.

- [ ] **Step 3: Replace `CatatViewModel.swift`**

Full content of `UcapHutang/Features/Catat/ViewModels/CatatViewModel.swift`:

```swift
import Foundation
import Observation

@Observable
final class CatatViewModel {
    let flow: CaptureFlow
    var createdDraftID: UUID?
    let container: AppContainer
    let speechRecognizer = SpeechRecognizer()

    var liveTranscript = ""
    var isProcessing = false
    var errorMessage: String?
    private(set) var isStartingRecording = false

    @ObservationIgnored private var activeProcessingID: UUID?
    @ObservationIgnored private var processingTask: Task<Void, Never>?

    init(flow: CaptureFlow, container: AppContainer) {
        self.flow = flow
        self.container = container
    }

    var stageHeadline: String {
        if isProcessing { return "Menganalisis data..." }
        if speechRecognizer.state == .finalizing { return "Menyelesaikan transkrip..." }
        if isStartingRecording || speechRecognizer.isRecording { return "Mendengarkan..." }
        return ""
    }

    func handleMicTap() {
        guard activeProcessingID == nil else { return }
        if speechRecognizer.isRecording {
            finishAndProcess()
        } else {
            startRecording()
        }
    }

    func restartRecording() {
        guard activeProcessingID == nil else { return }
        speechRecognizer.cancelRecording()
        startRecording()
    }

    func handleSpeechStateChange(_ state: SpeechRecognizerState) {
        switch state {
        case .listening:
            isStartingRecording = false
        case .failed, .idle:
            if !isProcessing { isStartingRecording = false }
        case .finalizing:
            break
        }
    }

    private func startRecording() {
        liveTranscript = ""
        isStartingRecording = true
        speechRecognizer.startRecording { [weak self] transcript in
            self?.liveTranscript = transcript
        }
    }

    private func finishAndProcess() {
        guard activeProcessingID == nil else { return }
        let requestID = UUID()
        activeProcessingID = requestID
        isProcessing = true
        processingTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.activeProcessingID == requestID {
                    self.activeProcessingID = nil
                    self.processingTask = nil
                    self.isProcessing = false
                }
            }
            let finalTranscript = await self.speechRecognizer.finishRecording()
            guard !Task.isCancelled, self.activeProcessingID == requestID else { return }
            let clean = finalTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? self.liveTranscript : finalTranscript
            guard !clean.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                self.errorMessage = "Suara tidak terdeteksi. Silakan coba lagi."
                return
            }
            do {
                let draft = try await self.container.extractionService.extract(DraftExtractionRequest(flow: self.flow, transcript: clean))
                try Task.checkCancellation()
                try await self.container.repository.saveDraft(draft)
                try Task.checkCancellation()
                self.createdDraftID = draft.id
            } catch {
                guard !Task.isCancelled else { return }
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func cancel() {
        speechRecognizer.cancelRecording()
        processingTask?.cancel()
        processingTask = nil
        activeProcessingID = nil
        isStartingRecording = false
    }
}
```

- [ ] **Step 4: Replace `CatatView.swift`**

Full content of `UcapHutang/Features/Catat/Views/CatatView.swift`:

```swift
import SwiftUI

struct CatatView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CatatViewModel

    let flow: CaptureFlow

    init(flow: CaptureFlow, container: AppContainer) {
        self.flow = flow
        _viewModel = State(initialValue: CatatViewModel(flow: flow, container: container))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    Button { viewModel.handleMicTap() } label: {
                        recordingControl
                    }
                    .disabled(viewModel.isProcessing)

                    if isListening {
                        Button("Ulangi") { viewModel.restartRecording() }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(AppColors.surface)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppColors.border))

                        Text(viewModel.liveTranscript.isEmpty ? viewModel.stageHeadline : viewModel.liveTranscript)
                            .font(viewModel.liveTranscript.isEmpty ? .body : .body.weight(.medium))
                            .foregroundStyle(viewModel.liveTranscript.isEmpty ? AppColors.textSecondary : AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                            .animation(.easeInOut(duration: 0.2), value: viewModel.liveTranscript)
                    } else if !viewModel.isProcessing {
                        Text("Tip: \(tipText)")
                            .font(.body)
                            .foregroundStyle(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationTitle(flow.title)
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear { viewModel.cancel() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { viewModel.cancel(); dismiss() }
                }
            }
            .alert("Gagal Memproses", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) { Button("OK", role: .cancel) {} } message: {
                Text(viewModel.errorMessage ?? "Terjadi kesalahan.")
            }
            .onChange(of: viewModel.speechRecognizer.errorMessage) { _, message in
                if let message { viewModel.errorMessage = message }
            }
            .onChange(of: viewModel.speechRecognizer.state) { _, state in
                viewModel.handleSpeechStateChange(state)
            }
            .navigationDestination(item: $viewModel.createdDraftID) { draftID in
                ReviewDraftView(draftID: draftID, repository: viewModel.container.repository)
            }
        }
    }

    private var isListening: Bool {
        viewModel.isStartingRecording || viewModel.speechRecognizer.isRecording
    }

    private var recordingControl: some View {
        ZStack {
            Circle()
                .stroke(
                    AppColors.textSecondary.opacity(0.65),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [7, 7])
                )
                .frame(width: 250, height: 250)
            if viewModel.isProcessing || viewModel.speechRecognizer.state == .finalizing {
                ProgressView().tint(AppColors.textPrimary).scaleEffect(1.3)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: isListening ? "stop.fill" : "play.fill")
                        .font(.system(size: 34, weight: .bold))
                    Text(isListening ? "Tekan untuk\nberhenti" : "Tekan untuk catat\nvia suara")
                        .font(.title3.weight(.bold))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(AppColors.textPrimary)
            }
        }
        .frame(width: 250, height: 250)
    }

    private var tipText: String {
        flow == .personal
            ? "Dito pinjam 50 ribu buat beli bensin"
            : "Split bill makan 100 ribu sama Satria dan Arif bagi rata"
    }
}
```

- [ ] **Step 5: Build and test**

Run the full test command. Expected: `Executed 21 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add UcapHutang/Features/Catat UcapHutang/Services/Speech/SpeechRecognizer.swift
git commit -m "refactor: organize Catat feature and migrate speech state to @Observable"
```

---

### Task 5: App shell — `@Observable` container, environment injection, `Tab` API

**Files:**
- Replace: `UcapHutang/App/AppContainer.swift` (drops the unused `PreviewData` enum)
- Replace: `UcapHutang/UcapHutangApp.swift`
- Replace: `UcapHutang/App/ContentView.swift`
- Replace: `UcapHutang/App/RootTabView.swift`

**Interfaces:**
- Consumes: `ReviewListView`, `ReviewDetailView`, `CatatFlowChooserView`, `CatatView`, `LedgerListView`, `CaptureFlow`.
- Produces (used by P3–P6):
  - `@Observable final class AppContainer` — `repository: any TransactionRepository`, `extractionService: any DraftExtractionService`, `storageErrorMessage: String?`, `init(repository:extractionService:storageErrorMessage:)`, `static func makeDefault() -> AppContainer`.
  - Injection: `ContentView().environment(container)`; read with `@Environment(AppContainer.self) private var container`.
  - `enum AppTab: Hashable { case review, capture, ledger }`.
  - `struct IdentifiableUUID: Identifiable, Equatable` (unchanged, still in `RootTabView.swift`).

- [ ] **Step 1: Replace `AppContainer.swift`**

Full content of `UcapHutang/App/AppContainer.swift`:

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
        do {
            let schema = Schema([
                SDTransactionParticipant.self,
                SDTransactionDraft.self,
                SDLedgerEntry.self
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: config)
            let repo = SwiftDataTransactionRepository(modelContainer: container)
            let extraction = HybridQwenExtractionService(llmClient: MLXQwenClient())
            return AppContainer(repository: repo, extractionService: extraction)
        } catch {
            let fallbackRepo = InMemoryTransactionRepository()
            let extraction = HybridQwenExtractionService(llmClient: MLXQwenClient())
            let message = "Penyimpanan lokal tidak dapat dibuka. Demi mencegah kehilangan data, pencatatan dinonaktifkan sementara. Tutup lalu buka kembali aplikasi. Detail: \(error.localizedDescription)"
            return AppContainer(
                repository: fallbackRepo,
                extractionService: extraction,
                storageErrorMessage: message
            )
        }
    }
}
```

Before saving, confirm `PreviewData` has no callers:

```bash
grep -rn --include='*.swift' "PreviewData" UcapHutang UcapHutangTests
```

Expected: **no output** after the replacement above.

- [ ] **Step 2: Replace `UcapHutangApp.swift`**

Full content of `UcapHutang/UcapHutangApp.swift`:

```swift
import SwiftUI

@main
struct UcapHutangApp: App {
    @State private var container = AppContainer.makeDefault()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(container)
        }
    }
}
```

- [ ] **Step 3: Replace `ContentView.swift`**

Full content of `UcapHutang/App/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        if let message = container.storageErrorMessage {
            ContentUnavailableView {
                Label("Penyimpanan Tidak Tersedia", systemImage: "externaldrive.badge.exclamationmark")
            } description: {
                Text(message)
            }
            .padding()
        } else {
            RootTabView()
        }
    }
}

#Preview {
    ContentView()
        .environment(AppContainer.makeDefault())
}
```

- [ ] **Step 4: Replace `RootTabView.swift`**

Full content of `UcapHutang/App/RootTabView.swift`:

```swift
import SwiftUI

struct IdentifiableUUID: Identifiable, Equatable {
    let id: UUID
    init(_ id: UUID) { self.id = id }
}

enum AppTab: Hashable {
    case review
    case capture
    case ledger
}

struct RootTabView: View {
    @Environment(AppContainer.self) private var container
    @State private var selectedTab: AppTab = .review
    @State private var reviewDraftItem: IdentifiableUUID?
    @State private var selectedCaptureFlow: CaptureFlow?

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Review", systemImage: "doc.badge.clock", value: AppTab.review) {
                ReviewListView(repository: container.repository) { draftID in
                    reviewDraftItem = IdentifiableUUID(draftID)
                }
            }

            Tab("Catat", systemImage: "mic.fill", value: AppTab.capture) {
                CatatFlowChooserView { flow in
                    selectedCaptureFlow = flow
                }
            }

            Tab("Riwayat", systemImage: "book.closed", value: AppTab.ledger) {
                LedgerListView(repository: container.repository)
            }
        }
        .sheet(item: $reviewDraftItem) { item in
            NavigationStack {
                ReviewDetailView(draftID: item.id, repository: container.repository)
            }
        }
        .sheet(item: $selectedCaptureFlow) { flow in
            CatatView(flow: flow, container: container)
        }
    }
}
```

- [ ] **Step 5: Build and test**

Run the full test command. Expected: `Executed 21 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add UcapHutang/App/AppContainer.swift UcapHutang/UcapHutangApp.swift UcapHutang/App/ContentView.swift UcapHutang/App/RootTabView.swift
git commit -m "refactor: inject @Observable AppContainer via environment and adopt Tab API"
```

---

### Task 6: Structure verification and simulator smoke check

**Files:** none changed (unless a check fails — then fix only what the check names and re-run).

- [ ] **Step 1: No legacy state-management APIs outside `Legacy/`**

```bash
grep -rn --include='*.swift' -E "ObservableObject|@Published|@StateObject|@ObservedObject|@EnvironmentObject|environmentObject\(|import Combine" UcapHutang | grep -v "UcapHutang/Features/Review/Legacy/"
```

Expected: **no output**.

- [ ] **Step 2: No duplicate formatters, no ViewModel protocols, no UIKit in ViewModels**

```bash
grep -rn --include='*.swift' -E "formatRupiah|ViewModelProtocol" UcapHutang
grep -rln --include='*.swift' -E "import (UIKit|SwiftUI|SwiftData|Contacts|Speech|AVFoundation|UserNotifications)|UIApplication" UcapHutang/Features/*/ViewModels
```

Expected: **no output** from both commands.

- [ ] **Step 3: Old locations are gone and the project file is untouched**

```bash
for p in UcapHutang/Features/Draft UcapHutang/Features/Ledger UcapHutang/Features/Components.swift UcapHutang/ContentView.swift UcapHutang/Domain/Repositories UcapHutang/Core/Utilities/QwenOutputDecoder.swift UcapHutang/Core/Utilities/TransactionDateResolver.swift UcapHutang/Domain/Models/DraftValidator.swift UcapHutang/Domain/Models/SwiftDataEntities.swift; do test -e "$p" && echo "STILL EXISTS: $p"; done
find UcapHutang -type d -empty -not -path "*/Resources/*"
git diff --quiet HEAD~5 -- UcapHutang.xcodeproj/project.pbxproj && echo "pbxproj unchanged"
```

Expected: no `STILL EXISTS` lines, no empty directories printed, and `pbxproj unchanged`.

- [ ] **Step 4: Full test suite**

Run the full test command. Expected: `Executed 21 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Simulator smoke check (screenshot for the developer)**

```bash
xcodebuild build -project UcapHutang.xcodeproj -scheme UcapHutang -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath build/DerivedData -quiet
xcrun simctl boot "iPhone 17" 2>/dev/null || true
xcrun simctl install "iPhone 17" build/DerivedData/Build/Products/Debug-iphonesimulator/UcapHutang.app
xcrun simctl launch "iPhone 17" AdhiKrisna.UcapHutang
sleep 5
xcrun simctl io "iPhone 17" screenshot build/p1-tabs.png
```

Expected: the build prints no `error:` lines; `simctl launch` prints `AdhiKrisna.UcapHutang: <pid>`; `build/p1-tabs.png` exists (`build/` is git-ignored). Report the screenshot path to the developer and ask them to confirm the tab bar shows **Review** (`doc.badge.clock`), **Catat**, **Riwayat**. If more than one "iPhone 17" simulator exists and `simctl` complains, use the UDID for iOS 26.5 from `xcrun simctl list devices available`.

- [ ] **Step 6: Final status**

```bash
git status --porcelain
git log --oneline -5
```

Expected: `git status` shows only `?? .xcede/` and `?? xcede.yml`; the log shows the five P1 commits (Tasks 1–5).
