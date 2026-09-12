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
        contacts: FakeContactsProvider? = nil
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
            contacts: contacts ?? FakeContactsProvider()
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
