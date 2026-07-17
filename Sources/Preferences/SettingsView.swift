import AppKit
import Combine
import SwiftUI

final class SettingsNavigation: ObservableObject {
    @Published var selectedTab: SettingsTab

    init(selectedTab: SettingsTab = .general) {
        self.selectedTab = selectedTab
    }
}

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var navigation: SettingsNavigation
    @State private var showMenuBarHiddenAlert = false
    let openLoginItems: () -> Void
    let launchAtLoginStatusProvider: () -> LaunchAtLoginStatus

    init(
        settings: SettingsStore,
        navigation: SettingsNavigation = SettingsNavigation(),
        openLoginItems: @escaping () -> Void = LaunchAtLoginManager.openSystemSettingsLoginItems,
        launchAtLoginStatusProvider: @escaping () -> LaunchAtLoginStatus = { LaunchAtLoginManager().status },
    ) {
        self.settings = settings
        self.navigation = navigation
        self.openLoginItems = openLoginItems
        self.launchAtLoginStatusProvider = launchAtLoginStatusProvider
    }

    var body: some View {
        VStack(spacing: 14) {
            SettingsTabStrip(selectedTab: $navigation.selectedTab)

            Group {
                switch navigation.selectedTab {
                case .general:
                    GeneralSettingsPane(
                        settings: settings,
                        showMenuBarHiddenAlert: $showMenuBarHiddenAlert,
                        openLoginItems: openLoginItems,
                    )
                case .capture:
                    CaptureSettingsPane(settings: settings)
                case .output:
                    OutputSettingsPane(settings: settings)
                case .preview:
                    PreviewSettingsPane(settings: settings)
                case .hotkeys:
                    HotkeySettingsPane(settings: settings)
                case .about:
                    AboutSettingsPane()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
        .frame(minWidth: 620, minHeight: 460)
        .alert("Menu Bar Icon Hidden", isPresented: $showMenuBarHiddenAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("To bring it back, open OneShot from Spotlight and turn this setting off.")
        }
        .onAppear(perform: refreshLaunchAtLoginStatus)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshLaunchAtLoginStatus()
        }
    }

    private func refreshLaunchAtLoginStatus() {
        settings.updateLaunchAtLoginStatus(launchAtLoginStatusProvider())
    }
}

private struct GeneralSettingsPane: View {
    @ObservedObject var settings: SettingsStore
    @Binding var showMenuBarHiddenAlert: Bool
    let openLoginItems: () -> Void

    var body: some View {
        SettingsForm {
            Section("General") {
                Toggle("Launch at login", isOn: $settings.autoLaunchEnabled)
                    .help("Start OneShot automatically after you sign in.")
                if let launchAtLoginMessage = settings.launchAtLoginMessage {
                    HStack(spacing: 8) {
                        Text(launchAtLoginMessage)
                            .font(.caption)
                            .foregroundStyle(
                                settings.launchAtLoginStatus == .requiresApproval
                                    ? Color.orange
                                    : Color.secondary,
                            )
                        if settings.launchAtLoginStatus == .requiresApproval {
                            Button("Open Login Items", action: openLoginItems)
                                .controlSize(.small)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                Toggle("Show menu bar icon", isOn: menuBarIconVisible)
                    .onChange(of: settings.menuBarIconHidden) { _, isHidden in
                        if isHidden {
                            showMenuBarHiddenAlert = true
                        }
                    }
                    .help("Show the OneShot icon in the menu bar.")
            }
        }
    }

    private var menuBarIconVisible: Binding<Bool> {
        Binding(
            get: { !settings.menuBarIconHidden },
            set: { settings.menuBarIconHidden = !$0 },
        )
    }
}

struct OutputSettingsPane: View {
    @ObservedObject var settings: SettingsStore
    @State private var customDirectoryError: String?
    @State private var customPathInput: String
    @FocusState private var customPathFocused: Bool
    private let filenamePreviewDate = Date()

    init(settings: SettingsStore) {
        self.settings = settings
        _customPathInput = State(initialValue: settings.customSavePath)
    }

    var body: some View {
        SettingsForm {
            Section("Output") {
                Group {
                    LabeledContent("Filename prefix") {
                        TextField("", text: $settings.filenamePrefix)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Filename prefix")
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Example: \(effectiveFilename)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .textSelection(.enabled)
                        if filenamePrefixWillBeShortened {
                            Text("The prefix will be shortened to fit macOS filename limits.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                .disabled(!settings.usesDiskOutput)
                .help(diskOutputHelp)

                Toggle("Copy to clipboard automatically", isOn: autoCopyBinding)
                    .disabled(settings.usesClipboardOnlyOutput)
                    .help(clipboardHelp)

                Group {
                    LabeledContent("Save location") {
                        Picker("", selection: $settings.saveLocationOption) {
                            ForEach(SaveLocationOption.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .labelsHidden()
                    }

                    if settings.saveLocationOption == .custom {
                        LabeledContent("Custom folder") {
                            HStack(spacing: 8) {
                                TextField("", text: $customPathInput)
                                    .textFieldStyle(.roundedBorder)
                                    .accessibilityLabel("Custom folder")
                                    .focused($customPathFocused)
                                    .onSubmit(commitCustomPath)
                                Button("Choose…") {
                                    chooseFolder()
                                }
                            }
                        }
                        if let customDirectoryError {
                            Text(customDirectoryError)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .disabled(!settings.usesDiskOutput)
                .help(diskOutputHelp)

                if !settings.previewEnabled {
                    Picker("Default output", selection: $settings.previewDisabledOutputBehavior) {
                        ForEach(PreviewDisabledOutputBehavior.allCases) { behavior in
                            Text(behavior.title)
                                .tag(behavior)
                                .help(behavior.helpText)
                        }
                    }
                    .help("Choose what happens when previews are disabled.")
                }
            }
        }
        .onChange(of: customPathFocused) { _, focused in
            if !focused {
                commitCustomPath()
            }
        }
        .onChange(of: settings.customSavePath) { _, newValue in
            if !customPathFocused, customPathInput != newValue {
                customPathInput = newValue
            }
        }
    }

    var effectiveFilename: String {
        FilenameFormatter.makeFilename(prefix: settings.filenamePrefix, date: filenamePreviewDate)
    }

    var filenamePrefixWillBeShortened: Bool {
        let oneCharacterFilename = FilenameFormatter.makeFilename(prefix: "x", date: filenamePreviewDate)
        let suffixBytes = oneCharacterFilename.utf8.count - 1
        let availableBytes = max(FilenameFormatter.maximumComponentBytes - suffixBytes, 1)
        return settings.filenamePrefix.utf8.count > availableBytes
    }

    var autoCopyBinding: Binding<Bool> {
        Binding(
            get: { settings.usesClipboardOnlyOutput || settings.autoCopyToClipboard },
            set: { settings.autoCopyToClipboard = $0 },
        )
    }

    var diskOutputHelp: String {
        settings.usesDiskOutput
            ? "Choose how screenshot files are named and where they are saved."
            : "Enable disk output to configure filenames and save locations."
    }

    var clipboardHelp: String {
        settings.usesClipboardOnlyOutput
            ? "Clipboard-only output always copies the screenshot."
            : "Copy captures to the clipboard in addition to saving."
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"

        if panel.runModal() == .OK, let url = panel.url, validateDirectory(url) {
            customDirectoryError = nil
            customPathInput = url.path
            settings.customSavePath = url.path
        }
    }

    private func commitCustomPath() {
        let expandedPath = (customPathInput as NSString).expandingTildeInPath
        guard !expandedPath.isEmpty else {
            customDirectoryError = "Choose a writable folder."
            return
        }

        let url = URL(fileURLWithPath: expandedPath, isDirectory: true)
        guard validateDirectory(url) else { return }
        customDirectoryError = nil
        customPathInput = url.path
        settings.customSavePath = url.path
    }

    @discardableResult
    private func validateDirectory(_ url: URL) -> Bool {
        do {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isWritableKey])
            guard values.isDirectory == true, values.isWritable == true else {
                customDirectoryError = "Choose a writable folder."
                return false
            }
            return true
        } catch {
            customDirectoryError = "OneShot couldn’t use that folder."
            return false
        }
    }
}

struct PreviewSettingsPane: View {
    @ObservedObject var settings: SettingsStore

    private let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimum = 0
        formatter.maximum = NSNumber(value: SettingsStore.maximumSaveDelaySeconds)
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    var body: some View {
        SettingsForm {
            Section("Preview") {
                Toggle("Show floating preview", isOn: $settings.previewEnabled)
                Toggle("Auto-dismiss preview", isOn: $settings.previewTimeoutEnabled)
                    .disabled(!settings.previewEnabled)
                if settings.previewEnabled {
                    LabeledContent("Save delay (seconds)") {
                        TextField("", value: $settings.saveDelaySeconds, formatter: numberFormatter)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 80)
                            .accessibilityLabel("Save delay in seconds")
                    }
                    .disabled(!settings.previewTimeoutEnabled)
                    .help(
                        settings.previewTimeoutEnabled
                            ? "Choose how long the preview remains visible."
                            : "Enable auto-dismiss to set a save delay.",
                    )
                    Picker("On preview timeout", selection: $settings.previewAutoDismissBehavior) {
                        ForEach(PreviewAutoDismissBehavior.allCases) { behavior in
                            Text(behavior.title)
                                .tag(behavior)
                                .help(behavior.helpText)
                        }
                    }
                    .disabled(!settings.previewTimeoutEnabled)
                    .help("Choose what happens when the preview timer ends.")
                }
                Picker("On new screenshot", selection: $settings.previewReplacementBehavior) {
                    ForEach(PreviewReplacementBehavior.allCases) { behavior in
                        Text(behavior.title)
                            .tag(behavior)
                            .help(behavior.helpText)
                    }
                }
                .disabled(!settings.previewEnabled)
                .help(
                    "Choose what happens to the current preview when a new screenshot is taken " +
                        "and the old preview is still visible.",
                )
            }
        }
    }
}

private struct AboutSettingsPane: View {
    var body: some View {
        VStack(spacing: 12) {
            AboutView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SettingsForm<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        Form {
            content
        }
        .formStyle(.grouped)
    }
}
