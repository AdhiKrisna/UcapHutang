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
