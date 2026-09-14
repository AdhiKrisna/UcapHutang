import XCTest
@testable import UcapHutang

final class SonarPingTriggerTests: XCTestCase {
    private let trigger = SonarPingTrigger()
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testBelowThresholdNeverFires() {
        XCTAssertFalse(trigger.shouldFire(level: 0.5, now: now, lastFire: nil))
        XCTAssertFalse(trigger.shouldFire(level: 0.77, now: now, lastFire: now.addingTimeInterval(-10)))
    }

    func testAtOrAboveThresholdWithNoPriorFireFires() {
        XCTAssertTrue(trigger.shouldFire(level: 0.78, now: now, lastFire: nil))
        XCTAssertTrue(trigger.shouldFire(level: 0.95, now: now, lastFire: nil))
    }

    func testSecondCallInsideCooldownDoesNotFire() {
        let lastFire = now.addingTimeInterval(-0.5)
        XCTAssertFalse(trigger.shouldFire(level: 0.9, now: now, lastFire: lastFire))
    }

    func testCallAfterCooldownElapsedFiresAgain() {
        let lastFire = now.addingTimeInterval(-0.7)
        XCTAssertTrue(trigger.shouldFire(level: 0.9, now: now, lastFire: lastFire))
    }
}
