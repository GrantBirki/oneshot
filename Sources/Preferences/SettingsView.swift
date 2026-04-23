import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @State private var selectedTab: SettingsTab = .general
    @State private var showMenuBarHiddenAlert = false

    var body: some View {
        VStack(spacing: 14) {
            SettingsTabStrip(selectedTab: $selectedTab)

            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsPane(
                        settings: settings,
                        showMenuBarHiddenAlert: $showMenuBarHiddenAlert,
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
    }
}

private struct GeneralSettingsPane: View {
    @ObservedObject var settings: SettingsStore
    @Binding var showMenuBarHiddenAlert: Bool

    var body: some View {
        SettingsForm {
            Section("General") {
                Toggle("Launch at login", isOn: $settings.autoLaunchEnabled)
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

private struct OutputSettingsPane: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        SettingsForm {
            Section("Output") {
                LabeledContent("Filename prefix") {
                    TextField("", text: $settings.filenamePrefix)
                        .textFieldStyle(.roundedBorder)
                }

                Toggle("Copy to clipboard automatically", isOn: $settings.autoCopyToClipboard)
                    .help("Copy captures to the clipboard in addition to saving.")

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
                            TextField("", text: $settings.customSavePath)
                                .textFieldStyle(.roundedBorder)
                            Button("Choose...") {
                                chooseFolder()
                            }
                        }
                    }
                }

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
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"

        if panel.runModal() == .OK, let url = panel.url {
            settings.customSavePath = url.path
        }
    }
}

private struct PreviewSettingsPane: View {
    @ObservedObject var settings: SettingsStore

    private let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimum = 0
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
                    }
                    Picker("On preview timeout", selection: $settings.previewAutoDismissBehavior) {
                        ForEach(PreviewAutoDismissBehavior.allCases) { behavior in
                            Text(behavior.title)
                                .tag(behavior)
                                .help(behavior.helpText)
                        }
                    }
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
