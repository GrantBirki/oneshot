import Foundation
import SwiftUI

struct SemanticVersion: Comparable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    init?(_ rawValue: String) {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.first?.lowercased() == "v" {
            value.removeFirst()
        }

        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }

        guard
            let major = Self.parseComponent(parts[0]),
            let minor = Self.parseComponent(parts[1]),
            let patch = Self.parseComponent(parts[2])
        else {
            return nil
        }

        self.major = major
        self.minor = minor
        self.patch = patch
    }

    var description: String {
        "\(major).\(minor).\(patch)"
    }

    var displayValue: String {
        "v\(description)"
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        return lhs.patch < rhs.patch
    }

    private static func parseComponent(_ component: Substring) -> Int? {
        guard !component.isEmpty else { return nil }
        guard component.allSatisfy(\.isNumber) else { return nil }
        return Int(component)
    }
}

struct GitHubLatestRelease: Decodable, Equatable {
    let tagName: String
    let htmlURL: URL

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}

struct AvailableUpdate: Equatable {
    let version: SemanticVersion
    let releaseURL: URL
}

enum UpdateCheckOutcome: Equatable {
    case upToDate(currentVersion: SemanticVersion, latestVersion: SemanticVersion)
    case updateAvailable(currentVersion: SemanticVersion, latest: AvailableUpdate)
}

enum UpdateCheckError: Equatable, LocalizedError {
    case invalidCurrentVersion(String)
    case invalidReleaseVersion(String)
    case invalidResponse
    case httpStatus(Int)
    case untrustedResponseURL(String?)
    case untrustedReleaseURL(String)

    var errorDescription: String? {
        switch self {
        case .invalidCurrentVersion:
            "The installed version could not be checked."
        case .invalidReleaseVersion:
            "GitHub returned a release version OneShot could not understand."
        case .invalidResponse:
            "GitHub returned an unexpected response."
        case let .httpStatus(statusCode):
            if statusCode == 403 {
                "GitHub refused the update check. Try again later."
            } else {
                "GitHub returned HTTP \(statusCode)."
            }
        case .untrustedResponseURL,
             .untrustedReleaseURL:
            "GitHub returned an unexpected release URL."
        }
    }
}

struct UpdateCheckService {
    private let fetchLatestRelease: @Sendable () async throws -> GitHubLatestRelease

    init(fetchLatestRelease: @escaping @Sendable () async throws -> GitHubLatestRelease) {
        self.fetchLatestRelease = fetchLatestRelease
    }

    static let live = UpdateCheckService {
        try await GitHubReleaseClient().latestRelease()
    }

    func check(currentVersion rawCurrentVersion: String) async throws -> UpdateCheckOutcome {
        guard let currentVersion = SemanticVersion(rawCurrentVersion) else {
            throw UpdateCheckError.invalidCurrentVersion(rawCurrentVersion)
        }

        let release = try await fetchLatestRelease()
        guard let latestVersion = SemanticVersion(release.tagName) else {
            throw UpdateCheckError.invalidReleaseVersion(release.tagName)
        }
        guard Self.isTrustedReleaseURL(release.htmlURL) else {
            throw UpdateCheckError.untrustedReleaseURL(release.htmlURL.absoluteString)
        }

        if latestVersion > currentVersion {
            return .updateAvailable(
                currentVersion: currentVersion,
                latest: AvailableUpdate(version: latestVersion, releaseURL: release.htmlURL),
            )
        }

        return .upToDate(currentVersion: currentVersion, latestVersion: latestVersion)
    }

    static func isTrustedReleaseURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https" else { return false }
        guard url.host?.lowercased() == "github.com" else { return false }

        let pathComponents = url.pathComponents.map { $0.lowercased() }
        guard pathComponents.count == 6 else { return false }
        return pathComponents[0] == "/" &&
            pathComponents[1] == "grantbirki" &&
            pathComponents[2] == "oneshot" &&
            pathComponents[3] == "releases" &&
            pathComponents[4] == "tag"
    }
}

struct GitHubReleaseClient {
    private static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/GrantBirki/oneshot/releases/latest",
    )!

    func latestRelease() async throws -> GitHubLatestRelease {
        var request = URLRequest(url: Self.latestReleaseURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("OneShot/\(BuildInfo.appVersion ?? "0.0.0")", forHTTPHeaderField: "User-Agent")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 12

        let session = URLSession(configuration: configuration)
        defer {
            session.finishTasksAndInvalidate()
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UpdateCheckError.invalidResponse
        }
        guard Self.isTrustedResponseURL(httpResponse.url) else {
            throw UpdateCheckError.untrustedResponseURL(httpResponse.url?.absoluteString)
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            throw UpdateCheckError.httpStatus(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(GitHubLatestRelease.self, from: data)
    }

    private static func isTrustedResponseURL(_ url: URL?) -> Bool {
        guard let url else { return false }
        guard url.scheme?.lowercased() == "https" else { return false }
        guard url.host?.lowercased() == "api.github.com" else { return false }
        return url.path == "/repos/GrantBirki/oneshot/releases/latest"
    }
}

@MainActor
final class UpdateCheckViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case upToDate(version: SemanticVersion)
        case updateAvailable(version: SemanticVersion, releaseURL: URL)
        case failed(message: String)
    }

    @Published private(set) var state: State = .idle

    private let currentVersion: String
    private let service: UpdateCheckService

    init(
        currentVersion: String = BuildInfo.appVersion ?? "0.0.0",
        service: UpdateCheckService = .live,
    ) {
        self.currentVersion = currentVersion
        self.service = service
    }

    var isChecking: Bool {
        state == .checking
    }

    func checkForUpdates() async {
        guard !isChecking else { return }

        state = .checking

        do {
            switch try await service.check(currentVersion: currentVersion) {
            case let .upToDate(_, latestVersion):
                state = .upToDate(version: latestVersion)
            case let .updateAvailable(_, latest):
                state = .updateAvailable(version: latest.version, releaseURL: latest.releaseURL)
            }
        } catch {
            state = .failed(message: Self.failureMessage(for: error))
        }
    }

    private static func failureMessage(for error: Error) -> String {
        if let error = error as? UpdateCheckError,
           let message = error.errorDescription
        {
            return message
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "You appear to be offline."
            case .timedOut:
                return "The update check timed out."
            default:
                return "Unable to check for updates right now."
            }
        }

        return "Unable to check for updates right now."
    }
}
