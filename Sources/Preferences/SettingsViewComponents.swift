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
                .frame(width: 240, height: 28)

                if let conflictMessage {
                    Text(conflictMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .frame(width: 240, alignment: .leading)
                }
            }
            .padding(.trailing, 18)
        }
    }
}
