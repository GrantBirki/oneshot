import Foundation

enum SaveLocationOption: String, CaseIterable, Identifiable {
    case downloads
    case desktop
    case documents
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .downloads: "Downloads"
        case .desktop: "Desktop"
        case .documents: "Documents"
        case .custom: "Custom"
        }
    }
}

enum PreviewDisabledOutputBehavior: String, CaseIterable, Identifiable {
    case saveToDisk
    case clipboardOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .saveToDisk: "Save to disk"
        case .clipboardOnly: "Copy to clipboard"
        }
    }

    var helpText: String {
        switch self {
        case .saveToDisk:
            "Save screenshots to the selected location."
        case .clipboardOnly:
            "Copy screenshots to the clipboard without saving to disk."
        }
    }
}

enum PreviewReplacementBehavior: String, CaseIterable, Identifiable {
    case saveImmediately
    case discard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .saveImmediately:
            "Save previous capture"
        case .discard:
            "Discard previous capture"
        }
    }

    var helpText: String {
        switch self {
        case .saveImmediately:
            "Save the previous capture to disk immediately, then replace the preview."
        case .discard:
            "Cancel the previous capture without saving, then replace the preview."
        }
    }
}

enum PreviewAutoDismissBehavior: String, CaseIterable, Identifiable {
    case saveToDisk
    case discard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .saveToDisk:
            "Save to disk"
        case .discard:
            "Don't save to disk"
        }
    }

    var helpText: String {
        switch self {
        case .saveToDisk:
            "Save the capture when the preview timer ends."
        case .discard:
            "Discard the capture when the preview timer ends unless you save it manually."
        }
    }
}

enum SelectionDimmingMode: String, CaseIterable, Identifiable {
    case fullScreen = "macosLike"
    case selectionOnly = "inverse"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullScreen: "Full screen"
        case .selectionOnly: "Selection only"
        }
    }
}

enum SelectionVisualCue: String, CaseIterable, Identifiable {
    case pulse
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pulse: "Red pulse"
        case .none: "Disabled"
        }
    }
}
