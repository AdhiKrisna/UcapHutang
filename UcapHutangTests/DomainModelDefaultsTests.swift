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
