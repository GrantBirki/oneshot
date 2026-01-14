import AppKit

final class OutputCoordinator {
    private let settings: SettingsStore
    private let queue: DispatchQueue
    private let queueKey = DispatchSpecificKey<Void>()
    private let dateProvider: () -> Date
    private let clipboardCopy: (NSImage) -> Void
    private let onSave: ((UUID, URL) -> Void)?
    private var pendingSaves: [UUID: PendingSave] = [:]

    init(
        settings: SettingsStore,
        queue: DispatchQueue = DispatchQueue(label: "openshot.output", qos: .userInitiated),
        dateProvider: @escaping () -> Date = Date.init,
        clipboardCopy: @escaping (NSImage) -> Void = { ClipboardService.copy(image: $0) },
        onSave: ((UUID, URL) -> Void)? = nil
    ) {
        self.settings = settings
        self.queue = queue
        self.queue.setSpecific(key: queueKey, value: ())
        self.dateProvider = dateProvider
        self.clipboardCopy = clipboardCopy
        self.onSave = onSave
    }

    func begin(image: NSImage) -> UUID {
        clipboardCopy(image)

        let id = UUID()
        let delay = settings.saveDelaySeconds
        let schedule = { [weak self] in
            guard let self = self else { return }
            let workItem = DispatchWorkItem { [weak self] in
                self?.performSave(id: id)
            }
            self.pendingSaves[id] = PendingSave(
                image: image,
                workItem: workItem,
                savedURL: nil,
                releaseAfterSave: false
            )
            self.queue.asyncAfter(deadline: .now() + delay, execute: workItem)
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
            guard let self = self, var pending = self.pendingSaves[id] else { return }
            pending.workItem.cancel()
            if let savedURL = pending.savedURL {
                self.deleteSavedFile(at: savedURL)
            }
            self.pendingSaves.removeValue(forKey: id)
        }
    }

    func finalize(id: UUID) {
        queue.async { [weak self] in
            guard let self = self, var pending = self.pendingSaves[id] else { return }
            pending.workItem.cancel()
            if pending.savedURL == nil {
                pending.savedURL = self.saveNow(image: pending.image, id: id)
            }
            self.pendingSaves.removeValue(forKey: id)
        }
    }

    func markAutoDismissed(id: UUID) {
        queue.async { [weak self] in
            guard let self = self, var pending = self.pendingSaves[id] else { return }
            if pending.savedURL != nil {
                self.pendingSaves.removeValue(forKey: id)
            } else {
                pending.releaseAfterSave = true
                self.pendingSaves[id] = pending
            }
        }
    }

    private func performSave(id: UUID) {
        guard var pending = pendingSaves[id], !pending.workItem.isCancelled else {
            pendingSaves.removeValue(forKey: id)
            return
        }

        if pending.savedURL == nil {
            pending.savedURL = saveNow(image: pending.image, id: id)
        }

        if pending.releaseAfterSave {
            pendingSaves.removeValue(forKey: id)
        } else {
            pendingSaves[id] = pending
        }
    }

    private func saveNow(image: NSImage, id: UUID) -> URL? {
        let directory = SaveLocationResolver.resolve(
            option: settings.saveLocationOption,
            customPath: settings.customSavePath
        )
        let filename = FilenameFormatter.makeFilename(prefix: settings.filenamePrefix, date: dateProvider())

        do {
            let url = try FileSaveService.save(image: image, to: directory, filename: filename)
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
    let image: NSImage
    var workItem: DispatchWorkItem
    var savedURL: URL?
    var releaseAfterSave: Bool
}
