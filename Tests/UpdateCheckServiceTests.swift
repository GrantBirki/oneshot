@testable import OneShot
import XCTest

final class UpdateCheckServiceTests: XCTestCase {
    func testDecodesGitHubLatestReleaseResponse() throws {
        let data = Data("""
        {
          "tag_name": "v1.2.3",
          "html_url": "https://github.com/GrantBirki/oneshot/releases/tag/v1.2.3"
        }
        """.utf8)

        let release = try JSONDecoder().decode(GitHubLatestRelease.self, from: data)

        XCTAssertEqual(release.tagName, "v1.2.3")
        XCTAssertEqual(
            release.htmlURL,
            URL(string: "https://github.com/GrantBirki/oneshot/releases/tag/v1.2.3"),
        )
    }

    func testReportsAvailableUpdateWhenGitHubReleaseIsNewer() async throws {
        let releaseURL = try XCTUnwrap(URL(string: "https://github.com/GrantBirki/oneshot/releases/tag/v1.1.0"))
        let service = serviceReturning(tagName: "v1.1.0", releaseURL: releaseURL)

        let outcome = try await service.check(currentVersion: "1.0.0")

        XCTAssertEqual(
            outcome,
            try .updateAvailable(
                currentVersion: XCTUnwrap(SemanticVersion("1.0.0")),
                latest: AvailableUpdate(
                    version: XCTUnwrap(SemanticVersion("1.1.0")),
                    releaseURL: releaseURL,
                ),
            ),
        )
    }

    func testReportsUpToDateWhenCurrentVersionMatchesLatestRelease() async throws {
        let releaseURL = try XCTUnwrap(URL(string: "https://github.com/GrantBirki/oneshot/releases/tag/v1.0.0"))
        let service = serviceReturning(tagName: "v1.0.0", releaseURL: releaseURL)

        let outcome = try await service.check(currentVersion: "1.0.0")

        XCTAssertEqual(
            outcome,
            try .upToDate(
                currentVersion: XCTUnwrap(SemanticVersion("1.0.0")),
                latestVersion: XCTUnwrap(SemanticVersion("1.0.0")),
            ),
        )
    }

    func testReportsUpToDateWhenCurrentVersionIsAheadOfLatestRelease() async throws {
        let releaseURL = try XCTUnwrap(URL(string: "https://github.com/GrantBirki/oneshot/releases/tag/v1.0.0"))
        let service = serviceReturning(tagName: "v1.0.0", releaseURL: releaseURL)

        let outcome = try await service.check(currentVersion: "1.1.0")

        XCTAssertEqual(
            outcome,
            try .upToDate(
                currentVersion: XCTUnwrap(SemanticVersion("1.1.0")),
                latestVersion: XCTUnwrap(SemanticVersion("1.0.0")),
            ),
        )
    }

    func testRejectsInvalidCurrentVersion() async throws {
        let releaseURL = try XCTUnwrap(URL(string: "https://github.com/GrantBirki/oneshot/releases/tag/v1.1.0"))
        let service = serviceReturning(tagName: "v1.1.0", releaseURL: releaseURL)

        do {
            _ = try await service.check(currentVersion: "dev")
            XCTFail("Expected invalid current version to throw.")
        } catch {
            XCTAssertEqual(error as? UpdateCheckError, .invalidCurrentVersion("dev"))
        }
    }

    func testRejectsInvalidReleaseVersion() async throws {
        let releaseURL = try XCTUnwrap(URL(string: "https://github.com/GrantBirki/oneshot/releases/tag/latest"))
        let service = serviceReturning(tagName: "latest", releaseURL: releaseURL)

        do {
            _ = try await service.check(currentVersion: "1.0.0")
            XCTFail("Expected invalid release version to throw.")
        } catch {
            XCTAssertEqual(error as? UpdateCheckError, .invalidReleaseVersion("latest"))
        }
    }

    func testRejectsUntrustedReleaseURL() async throws {
        let releaseURL = try XCTUnwrap(URL(string: "https://example.com/GrantBirki/oneshot/releases/tag/v1.1.0"))
        let service = serviceReturning(tagName: "v1.1.0", releaseURL: releaseURL)

        do {
            _ = try await service.check(currentVersion: "1.0.0")
            XCTFail("Expected untrusted release URL to throw.")
        } catch {
            XCTAssertEqual(
                error as? UpdateCheckError,
                .untrustedReleaseURL("https://example.com/GrantBirki/oneshot/releases/tag/v1.1.0"),
            )
        }
    }

    func testTrustedReleaseURLRequiresCanonicalGitHubReleaseTag() throws {
        XCTAssertTrue(
            try UpdateCheckService.isTrustedReleaseURL(
                XCTUnwrap(URL(string: "https://github.com/GrantBirki/oneshot/releases/tag/v1.2.3")),
            ),
        )
        XCTAssertFalse(
            try UpdateCheckService.isTrustedReleaseURL(
                XCTUnwrap(URL(string: "http://github.com/GrantBirki/oneshot/releases/tag/v1.2.3")),
            ),
        )
        XCTAssertFalse(
            try UpdateCheckService.isTrustedReleaseURL(
                XCTUnwrap(URL(string: "https://github.com/GrantBirki/other/releases/tag/v1.2.3")),
            ),
        )
        XCTAssertFalse(
            try UpdateCheckService.isTrustedReleaseURL(
                XCTUnwrap(URL(string: "https://github.com/GrantBirki/oneshot/actions/runs/1")),
            ),
        )
        XCTAssertFalse(
            try UpdateCheckService.isTrustedReleaseURL(
                XCTUnwrap(URL(string: "https://github.com/GrantBirki/oneshot/releases/tag/v1.2.3/extra")),
            ),
        )
    }

    private func serviceReturning(tagName: String, releaseURL: URL) -> UpdateCheckService {
        UpdateCheckService {
            GitHubLatestRelease(tagName: tagName, htmlURL: releaseURL)
        }
    }
}
