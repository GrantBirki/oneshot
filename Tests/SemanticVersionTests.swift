@testable import OneShot
import XCTest

final class SemanticVersionTests: XCTestCase {
    func testParsesReleaseVersions() throws {
        XCTAssertEqual(try XCTUnwrap(SemanticVersion("1.2.3")).description, "1.2.3")
        XCTAssertEqual(try XCTUnwrap(SemanticVersion("v1.2.3")).description, "1.2.3")
        XCTAssertEqual(try XCTUnwrap(SemanticVersion(" V1.2.3 ")).displayValue, "v1.2.3")
    }

    func testComparesVersionsByMajorMinorAndPatch() throws {
        XCTAssertLessThan(try XCTUnwrap(SemanticVersion("1.2.3")), try XCTUnwrap(SemanticVersion("1.2.4")))
        XCTAssertLessThan(try XCTUnwrap(SemanticVersion("1.2.9")), try XCTUnwrap(SemanticVersion("1.3.0")))
        XCTAssertLessThan(try XCTUnwrap(SemanticVersion("1.9.9")), try XCTUnwrap(SemanticVersion("2.0.0")))
        XCTAssertEqual(SemanticVersion("2.0.0"), SemanticVersion("v2.0.0"))
    }

    func testRejectsUnsupportedVersionStrings() {
        XCTAssertNil(SemanticVersion(""))
        XCTAssertNil(SemanticVersion("1"))
        XCTAssertNil(SemanticVersion("1.2"))
        XCTAssertNil(SemanticVersion("1.2.3.4"))
        XCTAssertNil(SemanticVersion("1.2.beta"))
        XCTAssertNil(SemanticVersion("1.2.3-beta"))
        XCTAssertNil(SemanticVersion("v"))
    }
}
