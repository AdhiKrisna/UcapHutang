# P5 — Riwayat: Link and Merge Legacy Unlinked People Implementation Plan

> **For agentic workers (Gemini 3.7 Flash):** Execute the tasks in order, one step at a time. Steps use checkbox (`- [ ]`) syntax — tick each one as you finish it. When a step gives a complete file, replace the **entire** file with it. Never skip a "run the test and confirm it fails" step. If an actual result differs from the "Expected" text, stop and report instead of improvising.

**Goal:** People already in Riwayat who were saved without a contact are clearly labeled, cannot record payments or send reminders until linked, and can be linked to an iPhone contact — merging with that contact's existing history after the user confirms.

**Architecture:** `PersonLedgerDetailViewModel` gains the Contacts permission flow, a merge decision (`pendingMerge`), and a call to `TransactionRepository.linkPerson(personID:to:)` (P2). The detail view reuses the P3 contact picker in single-select mode through a new plain initializer. The repository already refuses payments for unlinked people (P2), so the UI block is a convenience on top of a data-layer guarantee.

**Tech Stack:** SwiftUI (iOS 26.5), Observation, XCTest.

**Spec:** `docs/superpowers/specs/2026-09-12-voice-draft-remediation-design.md` (§3, §6.3–6.4, §9, §14 P5).

## Global Constraints

- Work on branch `fix/all`. **P0–P4 must be finished** and the developer must have confirmed the P4 checklist. Suite at start: 93 tests passing.
- **Never stage `.xcede/` or `xcede.yml`.** Always `git add` explicit paths; never `git add -A`, `git add .`, or `git commit -a`.
- Do not edit `UcapHutang.xcodeproj/project.pbxproj`.
- Build settings in effect (do not change): `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_VERSION = 5.0`.
- ViewModels import only `Foundation` and `Observation`. Views open URLs with `@Environment(\.openURL)`.
- Contacts access: `denied`, `restricted`, and `limited` count as denied; ask only when the user taps "Hubungkan ke Kontak".
- Layout, fonts, and colors of Riwayat screens are **not** redesigned here (P7 does that). Only add what this plan specifies.
- Exact user-facing copy (Indonesian) for this phase:

  | Where | Text |
  |-------|------|
  | Person card, unlinked | `Belum terhubung ke kontak` (SF Symbol `person.crop.circle.badge.exclamationmark`) |
  | Detail link card text | `Hubungkan orang ini ke kontak untuk mencatat pembayaran atau mengirim pengingat.` |
  | Detail link card button | `Hubungkan ke Kontak` |
  | Hint on blocked buttons | `Hubungkan orang ini ke kontak terlebih dahulu.` |
  | Reminder button (renamed) | `Ingatkan lewat Pesan` |
  | Merge dialog | title `Gabungkan riwayat?`, message `Riwayat “<nama lama>” akan digabung dengan “<nama kontak>”. Saldo akan dijumlahkan.`, buttons `Gabungkan` / `Batal` |
  | Contacts access alert | title `Akses Kontak Diperlukan`, message `UcapHutang perlu akses penuh ke Kontak agar setiap catatan terhubung ke orang yang tepat.`, buttons `Buka Pengaturan` / `Nanti` |
  | Link failure alert | title `Belum Bisa Menghubungkan`, message = error message, button `OK` |

- Full test command:

  ```bash
  xcodebuild test -project UcapHutang.xcodeproj -scheme UcapHutang -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | grep -E "Test Case '.*' (passed|failed)|error:|Executed [0-9]+ tests|TEST SUCCEEDED|TEST FAILED"
  ```

- Single test class command (replace `<Class>`):

  ```bash
  xcodebuild test -project UcapHutang.xcodeproj -scheme UcapHutang -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:UcapHutangTests/<Class> 2>&1 | grep -E "Test Case '.*' (passed|failed)|error:|Executed [0-9]+ tests|TEST SUCCEEDED|TEST FAILED"
  ```

Expected test totals: start 93 → Task 1: 101.

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `UcapHutang/Features/Riwayat/Models/LedgerUIModels.swift` | Replace | Adds `RiwayatAlert`. |
| `UcapHutang/Features/Riwayat/ViewModels/PersonLedgerDetailViewModel.swift` | Replace | Link/merge/permission flow. |
| `UcapHutang/Features/Riwayat/Views/PersonLedgerDetailView.swift` | Replace | Link card, blocked actions, picker, merge dialog, alerts. |
| `UcapHutang/Features/Riwayat/Components/PersonCardRow.swift` | Replace | Unlinked label. |
| `UcapHutang/Features/Riwayat/Views/LedgerListView.swift` | Modify | Passes `contacts` to the detail view. |
| `UcapHutang/Features/Review/Views/ReviewContactPickerSheet.swift` | Modify | Plain single/multi-select initializer. |
| `UcapHutang/App/RootTabView.swift` | Modify | Passes `contacts` to `LedgerListView`. |
| `UcapHutangTests/PersonLedgerDetailViewModelTests.swift` | Create | Link/merge behavior. |

---

### Task 1: Link and merge legacy people from the Riwayat detail screen

**Files:** all files in the table above.

**Interfaces:**
- Consumes: `TransactionRepository.linkPerson(personID:to:)`, `.ledgerEntries()`, `RepositoryError.personNotFound` (P2); `PersonLedgerSummary.isLinked`, `.contactIdentifier` (P2); `ContactsProviding`, `ContactsAccess`, `ContactRef` (P3); `ReviewContactPickerSheet`, `ReviewContactPickerViewModel` (P3); `FakeContactsProvider` test double (P3).
- Produces:
  - `enum RiwayatAlert: Identifiable, Equatable { case contactsAccessRequired, linkFailed(message: String) }` with `title: String`, `message: String`.
  - `PersonLedgerDetailViewModel.init(person: PersonLedgerSummary, entries: [LedgerEntry], repository: any TransactionRepository, contacts: any ContactsProviding)`; new members `isShowingContactPicker: Bool`, `pendingMerge: ContactRef?`, `isConfirmingMerge: Bool` (get/set), `alert: RiwayatAlert?`, `canRecordPaymentOrRemind: Bool`, `requestLink() async`, `handlePicked(_ contact: ContactRef) async`, `confirmMerge() async`, `cancelMerge()`.
  - `PersonLedgerDetailView.init(person:entries:repository:contacts:)`.
  - `LedgerListView.init(repository: any TransactionRepository, contacts: any ContactsProviding)`.
  - `ReviewContactPickerSheet.init(allowsMultipleSelection: Bool, initialQuery: String, contacts:repository:onPick:)` (the P3 `init(request:contacts:repository:onPick:)` stays and delegates to it).

- [ ] **Step 1: Write the failing tests**

Create `UcapHutangTests/PersonLedgerDetailViewModelTests.swift`:

```swift
import XCTest
@testable import UcapHutang

@MainActor
final class PersonLedgerDetailViewModelTests: XCTestCase {
    private let budiContact = ContactRef(identifier: "contact-budi", displayName: "Budi Santoso", phoneNumber: nil)

    private func entry(_ personID: String, _ name: String, _ delta: Int64, contact: String? = nil) -> LedgerEntry {
        LedgerEntry(personID: personID, personName: name, kind: .charge, balanceDelta: delta, date: .now, title: "Pulsa", contactIdentifier: contact)
    }

    private func makeViewModel(
        personID: String = "budi",
        displayName: String = "Budi",
        balance: Int64 = -10_000,
        contactIdentifier: String? = nil,
        seed: [LedgerEntry],
        contacts: FakeContactsProvider = FakeContactsProvider()
    ) -> (PersonLedgerDetailViewModel, InMemoryTransactionRepository) {
        let repository = InMemoryTransactionRepository(seedEntries: seed)
        let person = PersonLedgerSummary(
            id: personID,
            displayName: displayName,
            balance: balance,
            entryCount: seed.filter { $0.personID == personID }.count,
            lastActivity: .now,
            contactIdentifier: contactIdentifier
        )
        let viewModel = PersonLedgerDetailViewModel(
            person: person,
            entries: seed.filter { $0.personID == personID },
            repository: repository,
            contacts: contacts
        )
        return (viewModel, repository)
    }

    func testPaymentsAndRemindersAreBlockedOnlyForUnlinkedPeople() {
        let (unlinked, _) = makeViewModel(seed: [entry("budi", "Budi", -10_000)])
        XCTAssertFalse(unlinked.canRecordPaymentOrRemind)

        let (linked, _) = makeViewModel(
            personID: "contact-budi",
            contactIdentifier: "contact-budi",
            seed: [entry("contact-budi", "Budi Santoso", -10_000, contact: "contact-budi")]
        )
        XCTAssertTrue(linked.canRecordPaymentOrRemind)
    }

    func testRequestLinkWithDeniedAccessShowsContactsAlert() async {
        let (viewModel, _) = makeViewModel(seed: [entry("budi", "Budi", -10_000)], contacts: FakeContactsProvider(access: .denied))

        await viewModel.requestLink()

        XCTAssertEqual(viewModel.alert, .contactsAccessRequired)
        XCTAssertFalse(viewModel.isShowingContactPicker)
    }

    func testRequestLinkWithUndeterminedAccessAsksThenShowsPicker() async {
        let contacts = FakeContactsProvider(access: .notDetermined, accessAfterRequest: .authorized)
        let (viewModel, _) = makeViewModel(seed: [entry("budi", "Budi", -10_000)], contacts: contacts)

        await viewModel.requestLink()

        XCTAssertEqual(contacts.requestAccessCallCount, 1)
        XCTAssertTrue(viewModel.isShowingContactPicker)
        XCTAssertNil(viewModel.alert)
    }

    func testPickingAContactWithoutHistoryLinksImmediately() async throws {
        let (viewModel, repository) = makeViewModel(seed: [entry("budi", "Budi", -10_000)])

        await viewModel.handlePicked(budiContact)

        XCTAssertNil(viewModel.pendingMerge)
        XCTAssertEqual(viewModel.person.id, "contact-budi")
        XCTAssertEqual(viewModel.person.displayName, "Budi Santoso")
        XCTAssertTrue(viewModel.person.isLinked)
        XCTAssertEqual(viewModel.person.balance, -10_000)
        let entries = await repository.ledgerEntries()
        XCTAssertTrue(entries.allSatisfy { $0.personID == "contact-budi" })
    }

    func testPickingAContactWithHistoryAsksToMergeFirst() async throws {
        let seed = [
            entry("budi", "Budi", -10_000),
            entry("contact-budi", "Budi S", 25_000, contact: "contact-budi")
        ]
        let (viewModel, repository) = makeViewModel(seed: seed)

        await viewModel.handlePicked(budiContact)

        XCTAssertEqual(viewModel.pendingMerge, budiContact)
        XCTAssertTrue(viewModel.isConfirmingMerge)
        XCTAssertEqual(viewModel.person.id, "budi")
        let entries = await repository.ledgerEntries()
        XCTAssertEqual(entries.filter { $0.personID == "budi" }.count, 1, "Nothing moves before the user confirms")
    }

    func testConfirmingMergeLinksAndSumsBalances() async throws {
        let seed = [
            entry("budi", "Budi", -10_000),
            entry("contact-budi", "Budi S", 25_000, contact: "contact-budi")
        ]
        let (viewModel, _) = makeViewModel(seed: seed)
        await viewModel.handlePicked(budiContact)

        await viewModel.confirmMerge()

        XCTAssertNil(viewModel.pendingMerge)
        XCTAssertEqual(viewModel.person.id, "contact-budi")
        XCTAssertEqual(viewModel.person.balance, 15_000)
        XCTAssertEqual(viewModel.entries.count, 2)
        XCTAssertTrue(viewModel.person.isLinked)
    }

    func testCancellingMergeChangesNothing() async throws {
        let seed = [
            entry("budi", "Budi", -10_000),
            entry("contact-budi", "Budi S", 25_000, contact: "contact-budi")
        ]
        let (viewModel, repository) = makeViewModel(seed: seed)
        await viewModel.handlePicked(budiContact)

        viewModel.cancelMerge()

        XCTAssertNil(viewModel.pendingMerge)
        XCTAssertEqual(viewModel.person.id, "budi")
        let entries = await repository.ledgerEntries()
        XCTAssertEqual(entries.filter { $0.personID == "budi" }.count, 1)
    }

    func testLinkFailureShowsAlertAndKeepsPerson() async {
        let (viewModel, _) = makeViewModel(personID: "ghost", displayName: "Ghost", seed: [])

        await viewModel.handlePicked(budiContact)

        XCTAssertEqual(viewModel.alert, .linkFailed(message: "Orang ini tidak ditemukan di Riwayat. Muat ulang Riwayat."))
        XCTAssertEqual(viewModel.person.id, "ghost")
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run the single test class command with `<Class>` = `PersonLedgerDetailViewModelTests`.

Expected: `error:` lines such as `extra argument 'contacts' in call` and `value of type 'PersonLedgerDetailViewModel' has no member 'canRecordPaymentOrRemind'`; `** TEST FAILED **`.

- [ ] **Step 3: Add `RiwayatAlert`**

Replace the entire content of `UcapHutang/Features/Riwayat/Models/LedgerUIModels.swift` with:

```swift
import Foundation

// MARK: - Filter Enums
enum LedgerFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "Semua"
    case receivable = "Berutang ke kamu"
    case debt = "Kamu berutang"

    var id: String { rawValue }
}

enum DetailFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "Semua"
    case piutang = "Piutang"
    case utang = "Utang"
    case bayar = "Bayar"

    var id: String { rawValue }
}

// MARK: - Alerts
enum RiwayatAlert: Identifiable, Equatable {
    case contactsAccessRequired
    case linkFailed(message: String)

    var id: String {
        switch self {
        case .contactsAccessRequired: return "contacts-access"
        case .linkFailed: return "link-failed"
        }
    }

    var title: String {
        switch self {
        case .contactsAccessRequired: return "Akses Kontak Diperlukan"
        case .linkFailed: return "Belum Bisa Menghubungkan"
        }
    }

    var message: String {
        switch self {
        case .contactsAccessRequired:
            return "UcapHutang perlu akses penuh ke Kontak agar setiap catatan terhubung ke orang yang tepat."
        case .linkFailed(let message):
            return message
        }
    }
}
```

- [ ] **Step 4: Replace `PersonLedgerDetailViewModel.swift`**

Replace the entire content of `UcapHutang/Features/Riwayat/ViewModels/PersonLedgerDetailViewModel.swift` with:

```swift
import Foundation
import Observation

@Observable
final class PersonLedgerDetailViewModel {
    private(set) var person: PersonLedgerSummary
    private(set) var entries: [LedgerEntry]
    var selectedFilter: DetailFilter = .all
    var showingPayment: Bool = false
    var isShowingContactPicker = false
    var pendingMerge: ContactRef?
    var alert: RiwayatAlert?

    private let repository: any TransactionRepository
    private let contacts: any ContactsProviding

    init(
        person: PersonLedgerSummary,
        entries: [LedgerEntry],
        repository: any TransactionRepository,
        contacts: any ContactsProviding
    ) {
        self.person = person
        self.entries = entries
        self.repository = repository
        self.contacts = contacts
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

    /// Payments and reminders require a contact link (the repository enforces payments too).
    var canRecordPaymentOrRemind: Bool {
        person.isLinked
    }

    /// Drives the merge confirmation dialog.
    var isConfirmingMerge: Bool {
        get { pendingMerge != nil }
        set { if !newValue { pendingMerge = nil } }
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
            lastActivity: currentEntries.first?.date ?? person.lastActivity,
            contactIdentifier: currentEntries.lazy.compactMap(\.contactIdentifier).first
        )
    }

    // MARK: - Contact linking

    func requestLink() async {
        switch await contacts.access() {
        case .authorized:
            isShowingContactPicker = true
        case .denied:
            alert = .contactsAccessRequired
        case .notDetermined:
            if await contacts.requestAccess() == .authorized {
                isShowingContactPicker = true
            } else {
                alert = .contactsAccessRequired
            }
        }
    }

    /// Links right away, or asks for merge confirmation when the contact already has its own history.
    func handlePicked(_ contact: ContactRef) async {
        let allEntries = (try? await repository.ledgerEntries()) ?? []
        let contactHasOwnHistory = allEntries.contains {
            $0.personID == contact.identifier && $0.personID != person.id
        }
        if contactHasOwnHistory {
            pendingMerge = contact
        } else {
            await link(to: contact)
        }
    }

    func confirmMerge() async {
        guard let contact = pendingMerge else { return }
        pendingMerge = nil
        await link(to: contact)
    }

    func cancelMerge() {
        pendingMerge = nil
    }

    private func link(to contact: ContactRef) async {
        do {
            try await repository.linkPerson(personID: person.id, to: contact)
            person = PersonLedgerSummary(
                id: contact.identifier,
                displayName: contact.displayName,
                balance: person.balance,
                entryCount: person.entryCount,
                lastActivity: person.lastActivity,
                contactIdentifier: contact.identifier
            )
            await reload()
        } catch {
            alert = .linkFailed(message: error.localizedDescription)
        }
    }
}
```

- [ ] **Step 5: Add a plain initializer to the contact picker**

In `UcapHutang/Features/Review/Views/ReviewContactPickerSheet.swift`, replace the existing initializer:

```swift
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
```

with:

```swift
    init(
        allowsMultipleSelection: Bool,
        initialQuery: String,
        contacts: any ContactsProviding,
        repository: any TransactionRepository,
        onPick: @escaping ([ContactRef]) -> Void
    ) {
        _viewModel = State(initialValue: ReviewContactPickerViewModel(
            allowsMultipleSelection: allowsMultipleSelection,
            initialQuery: initialQuery,
            contacts: contacts,
            repository: repository
        ))
        self.onPick = onPick
    }

    init(
        request: ContactPickerRequest,
        contacts: any ContactsProviding,
        repository: any TransactionRepository,
        onPick: @escaping ([ContactRef]) -> Void
    ) {
        self.init(
            allowsMultipleSelection: request.allowsMultipleSelection,
            initialQuery: request.initialQuery,
            contacts: contacts,
            repository: repository,
            onPick: onPick
        )
    }
```

- [ ] **Step 6: Replace `PersonLedgerDetailView.swift`**

Replace the entire content of `UcapHutang/Features/Riwayat/Views/PersonLedgerDetailView.swift` with:

```swift
import SwiftUI

struct PersonLedgerDetailView: View {
    @State private var viewModel: PersonLedgerDetailViewModel
    @Environment(\.openURL) private var openURL
    private let repository: any TransactionRepository
    private let contacts: any ContactsProviding

    private let blockedActionHint = "Hubungkan orang ini ke kontak terlebih dahulu."

    init(
        person: PersonLedgerSummary,
        entries: [LedgerEntry],
        repository: any TransactionRepository,
        contacts: any ContactsProviding
    ) {
        self.repository = repository
        self.contacts = contacts
        _viewModel = State(initialValue: PersonLedgerDetailViewModel(
            person: person,
            entries: entries,
            repository: repository,
            contacts: contacts
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !viewModel.person.isLinked {
                    linkCard
                        .padding(.horizontal, 20)
                }

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

                    // Reminder Action Button
                    Button {
                        if let url = viewModel.reminderMessageURL {
                            openURL(url)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "message.fill")
                                .font(.subheadline)
                            Text("Ingatkan lewat Pesan")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Color(red: 1.0, green: 0.96, blue: 0.88))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canRecordPaymentOrRemind)
                    .accessibilityHint(viewModel.canRecordPaymentOrRemind ? "" : blockedActionHint)
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
                .disabled(!viewModel.canRecordPaymentOrRemind)
                .accessibilityHint(viewModel.canRecordPaymentOrRemind ? "" : blockedActionHint)
            }
        }
        .sheet(isPresented: $viewModel.showingPayment) {
            PaymentView(person: viewModel.person, repository: repository) {
                viewModel.showingPayment = false
                Task { await viewModel.reload() }
            }
        }
        .sheet(isPresented: $viewModel.isShowingContactPicker) {
            ReviewContactPickerSheet(
                allowsMultipleSelection: false,
                initialQuery: viewModel.person.displayName,
                contacts: contacts,
                repository: repository
            ) { picked in
                guard let contact = picked.first else { return }
                Task { await viewModel.handlePicked(contact) }
            }
        }
        .confirmationDialog(
            "Gabungkan riwayat?",
            isPresented: $viewModel.isConfirmingMerge,
            titleVisibility: .visible,
            presenting: viewModel.pendingMerge
        ) { _ in
            Button("Gabungkan") {
                Task { await viewModel.confirmMerge() }
            }
            Button("Batal", role: .cancel) {
                viewModel.cancelMerge()
            }
        } message: { contact in
            Text("Riwayat “\(viewModel.person.displayName)” akan digabung dengan “\(contact.displayName)”. Saldo akan dijumlahkan.")
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
            case .contactsAccessRequired:
                Button("Buka Pengaturan") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                Button("Nanti", role: .cancel) {}
            case .linkFailed:
                Button("OK", role: .cancel) {}
            }
        } message: { alert in
            Text(alert.message)
        }
        .task { await viewModel.reload() }
        .onReceive(NotificationCenter.default.publisher(for: .transactionRepositoryDidChange)) { _ in
            Task { await viewModel.reload() }
        }
    }

    private var linkCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Hubungkan orang ini ke kontak untuk mencatat pembayaran atau mengirim pengingat.")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .foregroundStyle(.orange)
            }

            Button {
                Task { await viewModel.requestLink() }
            } label: {
                Text("Hubungkan ke Kontak")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(.primary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }
}
```

- [ ] **Step 7: Label unlinked people in the list**

Replace the entire content of `UcapHutang/Features/Riwayat/Components/PersonCardRow.swift` with:

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

                if !person.isLinked {
                    Label("Belum terhubung ke kontak", systemImage: "person.crop.circle.badge.exclamationmark")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
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

- [ ] **Step 8: Pass `contacts` through the list and the tab**

In `UcapHutang/Features/Riwayat/Views/LedgerListView.swift`, replace:

```swift
    @State private var viewModel: LedgerListViewModel
    private let repository: any TransactionRepository

    init(repository: any TransactionRepository) {
        self.repository = repository
        _viewModel = State(initialValue: LedgerListViewModel(repository: repository))
    }
```

with:

```swift
    @State private var viewModel: LedgerListViewModel
    private let repository: any TransactionRepository
    private let contacts: any ContactsProviding

    init(repository: any TransactionRepository, contacts: any ContactsProviding) {
        self.repository = repository
        self.contacts = contacts
        _viewModel = State(initialValue: LedgerListViewModel(repository: repository))
    }
```

and replace:

```swift
                PersonLedgerDetailView(person: person, entries: viewModel.entries(for: person), repository: repository)
```

with:

```swift
                PersonLedgerDetailView(person: person, entries: viewModel.entries(for: person), repository: repository, contacts: contacts)
```

In `UcapHutang/App/RootTabView.swift`, replace:

```swift
                LedgerListView(repository: container.repository)
```

with:

```swift
                LedgerListView(repository: container.repository, contacts: container.contacts)
```

- [ ] **Step 9: Run to verify it passes**

Run the single test class command with `<Class>` = `PersonLedgerDetailViewModelTests`. Expected: `Executed 8 tests, with 0 failures`.

Run the full test command. Expected: `Executed 101 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 10: Verify the renamed label**

```bash
grep -rn --include='*.swift' "iMessage" UcapHutang
```

Expected: **no output**.

- [ ] **Step 11: Commit**

```bash
git add UcapHutang/Features/Riwayat/Models/LedgerUIModels.swift UcapHutang/Features/Riwayat/ViewModels/PersonLedgerDetailViewModel.swift UcapHutang/Features/Riwayat/Views/PersonLedgerDetailView.swift UcapHutang/Features/Riwayat/Components/PersonCardRow.swift UcapHutang/Features/Riwayat/Views/LedgerListView.swift UcapHutang/Features/Review/Views/ReviewContactPickerSheet.swift UcapHutang/App/RootTabView.swift UcapHutangTests/PersonLedgerDetailViewModelTests.swift
git commit -m "feat: require contact link for legacy Riwayat people with merge confirmation"
```

---

### Task 2: Device check (report to the developer)

**Files:** none changed.

- [ ] **Step 1: Simulator build smoke check**

```bash
xcodebuild build -project UcapHutang.xcodeproj -scheme UcapHutang -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath build/DerivedData -quiet
```

Expected: no `error:` lines.

- [ ] **Step 2: Hand the device checklist to the developer**

Send this checklist verbatim and wait for confirmation before starting P6. It needs a device with Riwayat data saved **before** P0 (people without contacts):

1. Riwayat list: a person saved without a contact shows "Belum terhubung ke kontak".
2. Open that person: the card "Hubungkan orang ini ke kontak untuk mencatat pembayaran atau mengirim pengingat." is visible; "Catat Bayar" and "Ingatkan lewat Pesan" are disabled; VoiceOver reads the hint "Hubungkan orang ini ke kontak terlebih dahulu."
3. Tap "Hubungkan ke Kontak" and pick a contact that has **no** Riwayat history → the title changes to the contact name, the card disappears, and both buttons become enabled.
4. For another unlinked person, pick a contact that **already has** Riwayat history → dialog "Gabungkan riwayat?" appears. **Batal** changes nothing; repeating and choosing **Gabungkan** leaves one person whose balance is the sum.
5. "Ingatkan lewat Pesan" on a linked person opens the Messages composer.

## Phase exit checklist

- [ ] `git status --porcelain` shows only `?? .xcede/` and `?? xcede.yml`.
- [ ] `git log --oneline -1` shows the P5 commit.
- [ ] Full test command: `Executed 101 tests, with 0 failures`, `** TEST SUCCEEDED **`.
- [ ] The developer confirmed the Task 2 checklist.
