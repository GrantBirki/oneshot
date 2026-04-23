import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case capture
    case output
    case preview
    case hotkeys
    case about

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .general:
            "General"
        case .capture:
            "Capture"
        case .output:
            "Output"
        case .preview:
            "Preview"
        case .hotkeys:
            "Hotkeys"
        case .about:
            "About"
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            "gearshape"
        case .capture:
            "camera.viewfinder"
        case .output:
            "square.and.arrow.down"
        case .preview:
            "photo"
        case .hotkeys:
            "keyboard"
        case .about:
            "info.circle"
        }
    }
}

struct SettingsTabStrip: View {
    @Binding var selectedTab: SettingsTab

    var body: some View {
        Picker("Settings section", selection: $selectedTab) {
            ForEach(SettingsTab.allCases) { tab in
                Label(tab.title, systemImage: tab.systemImage)
                    .labelStyle(.titleAndIcon)
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.large)
        .labelsHidden()
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel("Settings section")
    }
}
