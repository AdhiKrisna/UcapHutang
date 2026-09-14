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
