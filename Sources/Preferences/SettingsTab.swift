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
    @Namespace private var glassNamespace

    fileprivate enum Layout {
        static let selectedGlassID = "selected-settings-tab"
        static let animation = Animation.snappy(duration: 0.30, extraBounce: 0.05)
        static let glassSpacing: CGFloat = 24
        static let itemHeight: CGFloat = 36
        static let itemWidth: CGFloat = 88
        static let horizontalPadding: CGFloat = 14
        static let railPadding: CGFloat = 4
    }

    var body: some View {
        GlassEffectContainer(spacing: Layout.glassSpacing) {
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases) { tab in
                    SettingsTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        namespace: glassNamespace,
                        selectedGlassID: Layout.selectedGlassID,
                    ) {
                        withAnimation(Layout.animation) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(Layout.railPadding)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct SettingsTabButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let namespace: Namespace.ID
    let selectedGlassID: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            content
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(tab.title)
        .accessibilityHint("Shows the \(tab.title) settings.")
        .accessibilityValue(isSelected ? "Selected" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var content: some View {
        if isSelected {
            label
                .foregroundStyle(.primary)
                .glassEffect(.regular.tint(.accentColor), in: Capsule())
                .glassEffectID(selectedGlassID, in: namespace)
                .glassEffectTransition(.matchedGeometry)
        } else {
            label
                .foregroundStyle(Color.primary.opacity(isHovered ? 0.92 : 0.74))
                .background {
                    if isHovered {
                        Capsule()
                            .fill(Color.primary.opacity(0.06))
                    }
                }
        }
    }

    private var label: some View {
        Text(tab.title)
            .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
            .lineLimit(1)
            .padding(.horizontal, SettingsTabStrip.Layout.horizontalPadding)
            .frame(width: SettingsTabStrip.Layout.itemWidth, height: SettingsTabStrip.Layout.itemHeight)
            .contentShape(Capsule())
    }
}
