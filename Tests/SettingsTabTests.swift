@testable import OneShot
import XCTest

final class SettingsTabTests: XCTestCase {
    func testSettingsNavigationCanOpenAboutTab() {
        let navigation = SettingsNavigation()

        navigation.selectedTab = .about

        XCTAssertEqual(navigation.selectedTab, .about)
    }

    func testSettingsTabsAreInExpectedOrder() {
        XCTAssertEqual(
            SettingsTab.allCases.map(\.title),
            ["General", "Capture", "Output", "Preview", "Hotkeys", "About"],
        )
    }

    func testSettingsTabsHaveSystemImages() {
        XCTAssertEqual(
            SettingsTab.allCases.map(\.systemImage),
            [
                "gearshape",
                "camera.viewfinder",
                "square.and.arrow.down",
                "photo",
                "keyboard",
                "info.circle",
            ],
        )
    }

    func testSettingsTabsHaveStableUniqueIdentifiers() {
        let ids = SettingsTab.allCases.map(\.id)

        XCTAssertEqual(ids, ["general", "capture", "output", "preview", "hotkeys", "about"])
        XCTAssertEqual(Set(ids).count, ids.count)
    }
}
