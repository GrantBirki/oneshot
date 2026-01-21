import AppKit
import SwiftUI

struct HotkeyRecorderRow: View {
    let title: String
    @Binding var hotkey: Hotkey?
    let conflictMessage: String?

    var body: some View {
        LabeledContent(title) {
            VStack(alignment: .leading, spacing: 4) {
                HotkeyRecorder(
                    hotkey: $hotkey,
                    placeholder: "Type shortcut...",
                    accessibilityLabel: "\(title) hotkey",
                    showsConflict: conflictMessage != nil,
                )
                .frame(maxWidth: 200)

                if let conflictMessage {
                    Text(conflictMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

struct FocusClearView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.attach(to: nsView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        private weak var view: NSView?
        private var monitor: Any?

        func attach(to view: NSView) {
            self.view = view
            if monitor != nil {
                return
            }

            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
                guard let self,
                      let view = self.view,
                      let window = view.window,
                      window == event.window,
                      let contentView = window.contentView
                else {
                    return event
                }

                let point = contentView.convert(event.locationInWindow, from: nil)
                if let hitView = contentView.hitTest(point), isTextInput(view: hitView) {
                    return event
                }

                window.makeFirstResponder(nil)
                return event
            }
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        private func isTextInput(view: NSView) -> Bool {
            if view is NSTextView || view is NSTextField || view is HotkeyRecorderView {
                return true
            }

            var current = view.superview
            while let currentView = current {
                if currentView is NSTextField || currentView is HotkeyRecorderView {
                    return true
                }
                current = currentView.superview
            }

            return false
        }
    }
}
