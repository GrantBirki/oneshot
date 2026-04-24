import AppKit

@MainActor
final class OutputCoordinator {
    private let settings: SettingsStore
    private let dateProvider: () -> Date
    private let clipboardCopy: (Data) -> Void
    private let onSave: ((UUID, URL) -> Void)?
    private var pendingSaves: [UUID: PendingSave] = [:]

    init(
        settings: SettingsStore,
        queue _: DispatchQueue = DispatchQueue(label: "oneshot.output", qos: .userInitiated),
        dateProvider: @escaping () -> Date = Date.init,
        clipboardCopy: @escaping (Data) -> Void = { ClipboardService.copy(pngData: $0) },
        onSave: ((UUID, URL) -> Void)? = nil,
    ) {
        self.settings = settings
        self.dateProvider = dateProvider
        self.clipboardCopy = clipboardCopy
        self.onSave = onSave
    }

    func begin(pngData: Data, scheduleSave: Bool = true) -> UUID {
        let snapshot = OutputSettingsSnapshot(settings: settings)
        if snapshot.autoCopyToClipboard {
            clipboardCopy(pngData)
        }

        let id = UUID()
        let task = scheduleSave ? scheduledSaveTask(id: id, delay: snapshot.saveDelaySeconds) : nil
        pendingSaves[id] = PendingSave(
            pngData: pngData,
            snapshot: snapshot,
            task: task,
            savedURL: nil,
        )
        return id
    }

    func cancel(id: UUID) {
        guard let pending = pendingSaves[id] else { return }
        pending.task?.cancel()
        if let savedURL = pending.savedURL {
            deleteSavedFile(at: savedURL)
        }
        pendingSaves.removeValue(forKey: id)
    }

    func finalize(id: UUID, completion: (@MainActor @Sendable (URL?) -> Void)? = nil) {
        guard var pending = pendingSaves[id] else {
            completion?(nil)
            return
        }

        pending.task?.cancel()
        if pending.savedURL == nil {
            guard let pngData = pending.pngData else {
                pendingSaves.removeValue(forKey: id)
                completion?(nil)
                return
            }
            let savedURL = saveNow(pngData: pngData, snapshot: pending.snapshot, id: id)
            pending.savedURL = savedURL
            if savedURL != nil {
                pending.pngData = nil
            }
        }

        let savedURL = pending.savedURL
        pendingSaves.removeValue(forKey: id)
        completion?(savedURL)
    }

    private func scheduledSaveTask(id: UUID, delay: Double) -> Task<Void, Never> {
        Task { @MainActor [weak self] in
            let clampedDelay = max(delay, 0)
            if clampedDelay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(clampedDelay * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            self?.performSave(id: id)
        }
    }

    private func performSave(id: UUID) {
        guard var pending = pendingSaves[id], pending.task?.isCancelled != true else {
            pendingSaves.removeValue(forKey: id)
            return
        }

        if pending.savedURL == nil {
            guard let pngData = pending.pngData else {
                pendingSaves.removeValue(forKey: id)
                return
            }
            let savedURL = saveNow(pngData: pngData, snapshot: pending.snapshot, id: id)
            pending.savedURL = savedURL
            if savedURL != nil {
                pending.pngData = nil
            }
        }

        pendingSaves[id] = pending
    }

    private func saveNow(pngData: Data, snapshot: OutputSettingsSnapshot, id: UUID) -> URL? {
        let directory = snapshot.directory
        let filename = FilenameFormatter.makeFilename(prefix: snapshot.filenamePrefix, date: dateProvider())
        let signpostID = AppSignpost.begin("File save")
        defer {
            AppSignpost.end("File save", id: signpostID)
        }

        do {
            let url = try FileSaveService.save(pngData: pngData, to: directory, filename: filename)
            onSave?(id, url)
            return url
        } catch {
            AppLog.output.error("Failed to save screenshot: \(String(describing: error), privacy: .public)")
            AccessibilityAnnouncer.announce("Screenshot could not be saved")
            return nil
        }
    }

    private func deleteSavedFile(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            AppLog.output.error("Failed to delete screenshot: \(String(describing: error), privacy: .public)")
        }
    }
}

#if DEBUG
    extension OutputCoordinator {
        func pendingSaveCountForTesting() -> Int {
            pendingSaves.count
        }
    }
#endif

private struct PendingSave {
    var pngData: Data?
    let snapshot: OutputSettingsSnapshot
    var task: Task<Void, Never>?
    var savedURL: URL?
}

private struct OutputSettingsSnapshot {
    let autoCopyToClipboard: Bool
    let saveDelaySeconds: Double
    let directory: URL
    let filenamePrefix: String

    init(settings: SettingsStore) {
        autoCopyToClipboard = settings.autoCopyToClipboard
        saveDelaySeconds = settings.saveDelaySeconds
        directory = SaveLocationResolver.resolve(
            option: settings.saveLocationOption,
            customPath: settings.customSavePath,
        )
        filenamePrefix = settings.filenamePrefix
    }
}
