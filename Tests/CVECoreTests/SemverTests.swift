import XCTest
@testable import CVECore

final class SemverTests: XCTestCase {
    func testComparison() {
        XCTAssertTrue(Semver.lessThan("1.2.3", "1.2.4"))
        XCTAssertTrue(Semver.lessThan("1.9.0", "1.10.0"))
        XCTAssertFalse(Semver.lessThan("1.2.3", "1.2.3"))
    }
}
