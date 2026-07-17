import Foundation
@testable import OneShot
import XCTest

final class SaveLocationResolverTests: XCTestCase {
    func testDownloadsOptionUsesDownloadsDirectory() {
        let resolved = SaveLocationResolver.resolve(option: .downloads, customPath: "ignored")
        let expected = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]

        XCTAssertEqual(resolved, expected)
    }

    func testDesktopOptionUsesDesktopDirectory() {
        let resolved = SaveLocationResolver.resolve(option: .desktop, customPath: "ignored")
        let expected = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]

        XCTAssertEqual(resolved, expected)
    }

    func testDocumentsOptionUsesDocumentsDirectory() {
        let resolved = SaveLocationResolver.resolve(option: .documents, customPath: "ignored")
        let expected = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        XCTAssertEqual(resolved, expected)
    }

    func testCustomPathExpandsTilde() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let relative = "oneshot_test_\(UUID().uuidString)"
        let custom = "~/" + relative

        let resolved = SaveLocationResolver.resolve(option: .custom, customPath: custom)
        let expected = home.appendingPathComponent(relative).standardizedFileURL.resolvingSymlinksInPath()

        XCTAssertEqual(normalizedPath(resolved), normalizedPath(expected))
    }

    func testCustomPathRejectsRelativePath() {
        let resolved = SaveLocationResolver.resolve(option: .custom, customPath: "relative/path")
        let defaultURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]

        XCTAssertEqual(resolved, defaultURL)
    }

    func testCustomPathResolvesSymlink() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let target = root.appendingPathComponent("target")
        let link = root.appendingPathComponent("link")

        try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
        try fileManager.createSymbolicLink(atPath: link.path, withDestinationPath: target.path)
        defer { try? fileManager.removeItem(at: root) }

        let resolved = SaveLocationResolver.resolve(option: .custom, customPath: link.path)
        let expected = link.standardizedFileURL.resolvingSymlinksInPath()

        XCTAssertEqual(normalizedPath(resolved), normalizedPath(expected))
    }

    func testCustomPathEmptyFallsBackToDownloads() {
        let resolved = SaveLocationResolver.resolve(option: .custom, customPath: "  ")
        let defaultURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]

        XCTAssertEqual(resolved, defaultURL)
    }

    private func normalizedPath(_ url: URL) -> String {
        var path = url.standardizedFileURL.path
        if path.hasSuffix("/"), path.count > 1 {
            path.removeLast()
        }
        return path
    }
}
