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

    func testCreatedContactIsHandedBackInSingleSelection() async {
        let viewModel = ReviewContactPickerViewModel(
            allowsMultipleSelection: false,
            initialQuery: "Dito",
            contacts: FakeContactsProvider(contacts: [ari]),
            repository: InMemoryTransactionRepository()
        )
        XCTAssertEqual(viewModel.newContactName, "Dito")
        viewModel.searchQuery = "Andito "
        XCTAssertEqual(viewModel.newContactName, "Andito")
        viewModel.searchQuery = ""
        XCTAssertEqual(viewModel.newContactName, "Dito")

        let dito = ContactRef(identifier: "c-dito", displayName: "Andito Rizkika", phoneNumber: nil)
        let shouldClose = await viewModel.didCreateContact(dito)

        XCTAssertTrue(shouldClose)
        XCTAssertEqual(viewModel.selectedContacts, [])
    }

    func testCreatedContactIsSelectedAndShownInMultipleSelection() async {
        let provider = FakeContactsProvider(contacts: [ari, budi])
        let viewModel = ReviewContactPickerViewModel(
            allowsMultipleSelection: true,
            initialQuery: "",
            contacts: provider,
            repository: InMemoryTransactionRepository()
        )
        viewModel.toggle(ari)
        let dina = ContactRef(identifier: "c-dina", displayName: "Dina Putri", phoneNumber: nil)
        provider.allContacts.append(dina) // The system form saved it to Contacts.

        let shouldClose = await viewModel.didCreateContact(dina)

        XCTAssertFalse(shouldClose)
        XCTAssertEqual(viewModel.selectedContacts, [ari, dina])
        XCTAssertEqual(viewModel.searchQuery, "Dina Putri")
        XCTAssertEqual(viewModel.deviceContacts, [dina])
    }
}
