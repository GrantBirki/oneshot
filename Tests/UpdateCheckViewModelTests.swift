@testable import OneShot
import XCTest

@MainActor
final class UpdateCheckViewModelTests: XCTestCase {
    func testCheckForUpdatesPublishesAvailableUpdate() async throws {
        let releaseURL = try XCTUnwrap(URL(string: "https://github.com/GrantBirki/oneshot/releases/tag/v1.2.0"))
        let viewModel = UpdateCheckViewModel(
            currentVersion: "1.1.0",
            service: serviceReturning(tagName: "v1.2.0", releaseURL: releaseURL),
        )

        await viewModel.checkForUpdates()

        XCTAssertEqual(
            viewModel.state,
            try .updateAvailable(
                version: XCTUnwrap(SemanticVersion("1.2.0")),
                releaseURL: releaseURL,
            ),
        )
    }

    func testCheckForUpdatesPublishesUpToDateState() async throws {
        let releaseURL = try XCTUnwrap(URL(string: "https://github.com/GrantBirki/oneshot/releases/tag/v1.1.0"))
        let viewModel = UpdateCheckViewModel(
            currentVersion: "1.1.0",
            service: serviceReturning(tagName: "v1.1.0", releaseURL: releaseURL),
        )

        await viewModel.checkForUpdates()

        XCTAssertEqual(viewModel.state, try .upToDate(version: XCTUnwrap(SemanticVersion("1.1.0"))))
    }

    func testCheckForUpdatesPublishesHelpfulNetworkFailure() async {
        let viewModel = UpdateCheckViewModel(
            currentVersion: "1.1.0",
            service: UpdateCheckService {
                throw URLError(.notConnectedToInternet)
            },
        )

        await viewModel.checkForUpdates()

        XCTAssertEqual(viewModel.state, .failed(message: "You appear to be offline."))
    }

    func testCheckForUpdatesPublishesHelpfulGitHubFailure() async {
        let viewModel = UpdateCheckViewModel(
            currentVersion: "1.1.0",
            service: UpdateCheckService {
                throw UpdateCheckError.httpStatus(403)
            },
        )

        await viewModel.checkForUpdates()

        XCTAssertEqual(viewModel.state, .failed(message: "GitHub refused the update check. Try again later."))
    }

    private func serviceReturning(tagName: String, releaseURL: URL) -> UpdateCheckService {
        UpdateCheckService {
            GitHubLatestRelease(tagName: tagName, htmlURL: releaseURL)
        }
    }
}
