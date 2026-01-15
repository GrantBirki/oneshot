import SwiftUI

struct HotkeyRecorder: NSViewRepresentable {
    @Binding var hotkey: Hotkey?
    var placeholder: String = "Type shortcut..."
    var accessibilityLabel: String = "Hotkey"
    var showsConflict: Bool = false

    func makeCoordinator() -> Coordinator {
        Coordinator(hotkey: $hotkey)
    }

    func makeNSView(context: Context) -> HotkeyRecorderView {
        let view = HotkeyRecorderView()
        view.placeholderText = placeholder
        view.onChange = { [weak coordinator = context.coordinator] value in
            coordinator?.hotkey.wrappedValue = value
        }
        view.setAccessibilityLabel(accessibilityLabel)
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderView, context: Context) {
        context.coordinator.hotkey = $hotkey
        nsView.hotkey = hotkey
        nsView.placeholderText = placeholder
        nsView.setAccessibilityLabel(accessibilityLabel)
        nsView.showsConflict = showsConflict
    }

    final class Coordinator {
        var hotkey: Binding<Hotkey?>

        init(hotkey: Binding<Hotkey?>) {
            self.hotkey = hotkey
        }
    }
}
