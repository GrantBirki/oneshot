import AppKit
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    fileprivate enum Layout {
        static let animation = Animation.snappy(duration: 0.30, extraBounce: 0.05)
        static let itemSpacing: CGFloat = 8
        static let itemHeight: CGFloat = 36
        static let itemWidth: CGFloat = 88
        static let horizontalPadding: CGFloat = 14
        static let railPadding: CGFloat = 4
    }

    var body: some View {
        HStack(spacing: Layout.itemSpacing) {
            ForEach(SettingsTab.allCases) { tab in
                SettingsTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    reduceTransparency: reduceTransparency,
                ) {
                    withAnimation(currentAnimation) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(Layout.railPadding)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Settings section")
    }

    private var currentAnimation: Animation? {
        reduceMotion ? .linear(duration: 0.08) : Layout.animation
    }
}

private struct SettingsTabButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let reduceTransparency: Bool
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

    private var content: some View {
        label
            .foregroundStyle(Color.primary.opacity(isSelected ? 1 : (isHovered ? 0.92 : 0.74)))
            .background {
                if isSelected {
                    selectedBackground
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

    @ViewBuilder
    private var selectedBackground: some View {
        if reduceTransparency {
            Capsule()
                .fill(Color.accentColor.opacity(0.18))
                .overlay {
                    Capsule()
                        .stroke(Color.accentColor.opacity(0.55), lineWidth: 1)
                }
                .accessibilityHidden(true)
        } else {
            SettingsTabGlassBackground()
                .clipShape(Capsule())
                .accessibilityHidden(true)
        }
    }
}

private struct SettingsTabGlassBackground: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSGlassEffectView {
        let view = NSGlassEffectView()
        view.style = .regular
        view.tintColor = .controlAccentColor
        view.cornerRadius = SettingsTabStrip.Layout.itemHeight / 2
        return view
    }

    func updateNSView(_ view: NSGlassEffectView, context _: Context) {
        view.tintColor = .controlAccentColor
        view.cornerRadius = SettingsTabStrip.Layout.itemHeight / 2
    }
}
