import AppKit
import SwiftUI

struct CaptureSettingsPane: View {
    @ObservedObject var settings: SettingsStore
    @State var selectionDimmingHexInput: String
    @FocusState var selectionDimmingHexFocused: Bool
    let playShutterSound: @MainActor (
        ShutterSoundOption,
        Double,
        Bool,
    ) -> Void

    init(
        settings: SettingsStore,
        playShutterSound: @escaping @MainActor (
            ShutterSoundOption,
            Double,
            Bool,
        ) -> Void = { sound, volume, isEnabled in
            ScreenshotSoundPlayer.play(sound: sound, volume: volume, isEnabled: isEnabled)
        },
    ) {
        self.settings = settings
        self.playShutterSound = playShutterSound
        _selectionDimmingHexInput = State(initialValue: settings.selectionDimmingColorHex)
    }

    var body: some View {
        SettingsForm {
            Section("Selection") {
                Toggle("Show selection size", isOn: $settings.showSelectionCoordinates)
                    .help("Show the selection size next to the cursor.")
                Picker("Selection dimming", selection: $settings.selectionDimmingMode) {
                    ForEach(SelectionDimmingMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .help("Choose whether the overlay dims the full screen or only the selection.")
                LabeledContent("Selection color") {
                    HStack(spacing: 12) {
                        ColorPicker(
                            "",
                            selection: selectionDimmingColorBinding,
                            supportsOpacity: true,
                        )
                        .labelsHidden()
                        .accessibilityLabel("Selection color")
                        TextField("", text: $selectionDimmingHexInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .focused($selectionDimmingHexFocused)
                            .accessibilityLabel("Selection color hex value")
                            .onChange(of: selectionDimmingHexInput) { _, newValue in
                                updateSelectionDimmingHexInput(newValue)
                            }
                        Button("Reset") {
                            resetSelectionDimmingColor()
                        }
                        .help("Reset to the default selection color.")
                    }
                }
                .disabled(settings.selectionDimmingMode != .selectionOnly)
                .help(
                    settings.selectionDimmingMode == .selectionOnly
                        ? "Choose the selection-only fill color (RGBA hex)."
                        : "Choose Selection only dimming to customize the fill color.",
                )
                Picker("Selection visual cue", selection: $settings.selectionVisualCue) {
                    ForEach(SelectionVisualCue.allCases) { cue in
                        Text(cue.title).tag(cue)
                    }
                }
                .help("Choose a visual cue shown when selection mode starts.")
            }

            Section("Sound") {
                Toggle("Play shutter sound", isOn: $settings.shutterSoundEnabled)
                    .help("Play a sound when a screenshot is captured.")
                Picker("Shutter sound", selection: $settings.shutterSound) {
                    ForEach(ShutterSoundOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .disabled(!settings.shutterSoundEnabled)
                LabeledContent("Volume") {
                    HStack(spacing: 8) {
                        Slider(value: shutterSoundVolumeBinding, in: 0 ... 1)
                        Text("\(Int((settings.shutterSoundVolume * 100).rounded()))%")
                            .frame(width: 48, alignment: .trailing)
                        Button {
                            previewShutterSound()
                        } label: {
                            Label("Preview shutter sound", systemImage: "play.fill")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .help("Play the selected shutter sound at the current volume.")
                        .accessibilityLabel("Preview shutter sound")
                    }
                }
                .disabled(!settings.shutterSoundEnabled)
                .listRowSeparator(.hidden)
                .help("Set the shutter sound volume.")
            }
        }
        .onChange(of: selectionDimmingHexFocused) { _, focused in
            if !focused {
                normalizeSelectionDimmingHexInput()
            }
        }
        .onChange(of: settings.selectionDimmingColorHex) { _, newValue in
            if !selectionDimmingHexFocused, selectionDimmingHexInput != newValue {
                selectionDimmingHexInput = newValue
            }
        }
    }
}

extension CaptureSettingsPane {
    func updateSelectionDimmingHexInput(_ newValue: String) {
        let sanitized = sanitizeHexInput(newValue)
        if sanitized != newValue {
            selectionDimmingHexInput = sanitized
            return
        }
        let digitsCount = sanitized.filter(\.isHexDigit).count
        guard digitsCount == 6 || digitsCount == 8 else { return }
        guard let normalized = ColorHexCodec.normalized(sanitized) else { return }
        if normalized != settings.selectionDimmingColorHex {
            settings.selectionDimmingColorHex = normalized
        }
        if digitsCount == 8, normalized != selectionDimmingHexInput {
            selectionDimmingHexInput = normalized
        }
    }

    func sanitizeHexInput(_ value: String) -> String {
        let digits = value.filter(\.isHexDigit)
        guard !digits.isEmpty else { return "" }
        let limited = String(digits.prefix(8))
        return "#\(limited.uppercased())"
    }

    func normalizeSelectionDimmingHexInput() {
        let sanitized = sanitizeHexInput(selectionDimmingHexInput)
        guard let normalized = ColorHexCodec.normalized(sanitized) else {
            if selectionDimmingHexInput != settings.selectionDimmingColorHex {
                selectionDimmingHexInput = settings.selectionDimmingColorHex
            }
            return
        }
        if normalized != settings.selectionDimmingColorHex {
            settings.selectionDimmingColorHex = normalized
        }
        if normalized != selectionDimmingHexInput {
            selectionDimmingHexInput = normalized
        }
    }

    func resetSelectionDimmingColor() {
        let defaultHex = ColorHexCodec.defaultSelectionDimmingColorHex
        settings.selectionDimmingColorHex = defaultHex
        selectionDimmingHexInput = defaultHex
    }

    @MainActor
    func previewShutterSound() {
        playShutterSound(
            settings.shutterSound,
            settings.shutterSoundVolume,
            settings.shutterSoundEnabled,
        )
    }

    var shutterSoundVolumeBinding: Binding<Double> {
        Binding(
            get: { settings.shutterSoundVolume },
            set: { settings.shutterSoundVolume = roundedVolume($0) },
        )
    }

    var selectionDimmingColorBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: settings.selectionDimmingColor) },
            set: { settings.selectionDimmingColor = NSColor($0) },
        )
    }

    func roundedVolume(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        return (clamped * 100).rounded() / 100
    }
}
