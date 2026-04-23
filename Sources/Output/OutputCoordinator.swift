import AppKit

final class OutputCoordinator: @unchecked Sendable {
    private let settings: SettingsStore
    private let queue: DispatchQueue
    private let queueKey = DispatchSpecificKey<Void>()
    private let dateProvider: () -> Date
    private let clipboardCopy: (Data) -> Void
    private let onSave: ((UUID, URL) -> Void)?
    private var pendingSaves: [UUID: PendingSave] = [:]

    init(
        settings: SettingsStore,
        queue: DispatchQueue = DispatchQueue(label: "oneshot.output", qos: .userInitiated),
        dateProvider: @escaping () -> Date = Date.init,
        clipboardCopy: @escaping (Data) -> Void = { ClipboardService.copy(pngData: $0) },
        onSave: ((UUID, URL) -> Void)? = nil,
    ) {
        self.settings = settings
        self.queue = queue
        self.queue.setSpecific(key: queueKey, value: ())
        self.dateProvider = dateProvider
        self.clipboardCopy = clipboardCopy
        self.onSave = onSave
    }

    func begin(pngData: Data, scheduleSave: Bool = true) -> UUID {
        if settings.autoCopyToClipboard {
            clipboardCopy(pngData)
        }

        let id = UUID()
        let delay = settings.saveDelaySeconds
        let schedule = { [weak self] in
            guard let self else { return }
            let workItem = DispatchWorkItem { [weak self] in
                self?.performSave(id: id)
            }
            pendingSaves[id] = PendingSave(
                pngData: pngData,
                workItem: workItem,
                savedURL: nil,
            )
            if scheduleSave {
                queue.asyncAfter(deadline: .now() + delay, execute: workItem)
            }
        }
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            schedule()
        } else {
            queue.sync(execute: schedule)
        }
        return id
    }

    func cancel(id: UUID) {
        queue.async { [weak self] in
            guard let self, let pending = pendingSaves[id] else { return }
            pending.workItem.cancel()
            if let savedURL = pending.savedURL {
                deleteSavedFile(at: savedURL)
            }
            pendingSaves.removeValue(forKey: id)
        }
    }

    func finalize(id: UUID, completion: (@MainActor @Sendable (URL?) -> Void)? = nil) {
        let action: @Sendable () -> Void = { [weak self] in
            guard let self else { return }
            guard var pending = pendingSaves[id] else {
                dispatchCompletion(completion, nil)
                return
            }
            pending.workItem.cancel()
            if pending.savedURL == nil {
                guard let pngData = pending.pngData else {
                    pendingSaves.removeValue(forKey: id)
                    dispatchCompletion(completion, nil)
                    return
                }
                let savedURL = saveNow(pngData: pngData, id: id)
                pending.savedURL = savedURL
                if savedURL != nil {
                    pending.pngData = nil
                }
            }
            let savedURL = pending.savedURL
            pendingSaves.removeValue(forKey: id)
            dispatchCompletion(completion, savedURL)
        }
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            action()
        } else {
            queue.async(execute: action)
        }
    }

    private func dispatchCompletion(
        _ completion: (@MainActor @Sendable (URL?) -> Void)?,
        _ url: URL?,
    ) {
        guard let completion else { return }
        Task { @MainActor in
            completion(url)
        }
    }

    private func performSave(id: UUID) {
        guard var pending = pendingSaves[id], !pending.workItem.isCancelled else {
            pendingSaves.removeValue(forKey: id)
            return
        }

        if pending.savedURL == nil {
            guard let pngData = pending.pngData else {
                pendingSaves.removeValue(forKey: id)
                return
            }
            let savedURL = saveNow(pngData: pngData, id: id)
            pending.savedURL = savedURL
            if savedURL != nil {
                pending.pngData = nil
            }
        }

        pendingSaves[id] = pending
    }

    private func saveNow(pngData: Data, id: UUID) -> URL? {
        let directory = SaveLocationResolver.resolve(
            option: settings.saveLocationOption,
            customPath: settings.customSavePath,
        )
        let filename = FilenameFormatter.makeFilename(prefix: settings.filenamePrefix, date: dateProvider())

        do {
            let url = try FileSaveService.save(pngData: pngData, to: directory, filename: filename)
            onSave?(id, url)
            return url
        } catch {
            AppLog.output.error("Failed to save screenshot: \(String(describing: error), privacy: .public)")
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
            queue.sync {
                pendingSaves.count
            }
        }
    }
#endif

private struct PendingSave {
    var pngData: Data?
    var workItem: DispatchWorkItem
    var savedURL: URL?
}
