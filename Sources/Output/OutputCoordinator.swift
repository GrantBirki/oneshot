import AppKit

final class OutputCoordinator {
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
        clipboardCopy(pngData)

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
                releaseAfterSave: false,
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

    func finalize(id: UUID, completion: ((URL?) -> Void)? = nil) {
        let action = { [weak self] in
            guard let self else { return }
            guard var pending = pendingSaves[id] else {
                if let completion {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
                return
            }
            pending.workItem.cancel()
            if pending.savedURL == nil {
                pending.savedURL = saveNow(pngData: pending.pngData, id: id)
            }
            let savedURL = pending.savedURL
            pendingSaves.removeValue(forKey: id)
            if let completion {
                DispatchQueue.main.async {
                    completion(savedURL)
                }
            }
        }
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            action()
        } else {
            queue.async(execute: action)
        }
    }

    func markAutoDismissed(id: UUID) {
        queue.async { [weak self] in
            guard let self, var pending = pendingSaves[id] else { return }
            if pending.savedURL != nil {
                pendingSaves.removeValue(forKey: id)
            } else {
                pending.releaseAfterSave = true
                pendingSaves[id] = pending
            }
        }
    }

    private func performSave(id: UUID) {
        guard var pending = pendingSaves[id], !pending.workItem.isCancelled else {
            pendingSaves.removeValue(forKey: id)
            return
        }

        if pending.savedURL == nil {
            pending.savedURL = saveNow(pngData: pending.pngData, id: id)
        }

        if pending.releaseAfterSave {
            pendingSaves.removeValue(forKey: id)
        } else {
            pendingSaves[id] = pending
        }
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
            NSLog("Failed to save screenshot: \(error)")
            return nil
        }
    }

    private func deleteSavedFile(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            NSLog("Failed to delete screenshot: \(error)")
        }
    }
}

private struct PendingSave {
    let pngData: Data
    var workItem: DispatchWorkItem
    var savedURL: URL?
    var releaseAfterSave: Bool
}
