import AppKit

struct SavedOutput: Equatable, Sendable {
    let id: UUID
    let url: URL
    let wasAlreadySaved: Bool
}

enum OutputDestination: Equatable, Sendable {
    case configured
    case file(URL)
}

enum OutputError: LocalizedError, Sendable {
    case missingOutput
    case saveFailed(String)
    case deleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingOutput:
            "The screenshot is no longer available."
        case .saveFailed:
            "The screenshot could not be saved."
        case .deleteFailed:
            "The saved screenshot could not be deleted."
        }
    }

    var failureReason: String? {
        switch self {
        case .missingOutput:
            nil
        case let .saveFailed(reason), let .deleteFailed(reason):
            reason
        }
    }
}

actor OutputStore {
    typealias SaveFile = @Sendable (Data, URL, String) throws -> URL
    typealias SaveExactFile = @Sendable (Data, URL) throws -> URL
    typealias DeleteFile = @Sendable (URL) throws -> Void

    private struct PendingOutput: Sendable {
        let pngData: Data
        let snapshot: OutputSettingsSnapshot
        var savedURL: URL?
    }

    private var outputs: [UUID: PendingOutput] = [:]
    private let saveFile: SaveFile
    private let saveExactFile: SaveExactFile
    private let deleteFile: DeleteFile

    init(
        saveFile: @escaping SaveFile = { data, directory, filename in
            try FileSaveService.save(pngData: data, to: directory, filename: filename)
        },
        saveExactFile: @escaping SaveExactFile = { data, url in
            try FileSaveService.save(pngData: data, toFile: url)
        },
        deleteFile: @escaping DeleteFile = { url in
            try FileManager.default.removeItem(at: url)
        },
    ) {
        self.saveFile = saveFile
        self.saveExactFile = saveExactFile
        self.deleteFile = deleteFile
    }

    func insert(id: UUID, pngData: Data, snapshot: OutputSettingsSnapshot) {
        outputs[id] = PendingOutput(pngData: pngData, snapshot: snapshot, savedURL: nil)
    }

    func pngData(id: UUID) throws(OutputError) -> Data {
        guard let output = outputs[id] else {
            throw .missingOutput
        }
        return output.pngData
    }

    func save(
        id: UUID,
        destination: OutputDestination,
        date: Date,
    ) throws(OutputError) -> SavedOutput {
        try saveOutput(id: id, destination: destination, date: date)
    }

    func saveAndFinish(
        id: UUID,
        destination: OutputDestination,
        date: Date,
    ) throws(OutputError) -> SavedOutput {
        let result = try saveOutput(id: id, destination: destination, date: date)
        outputs.removeValue(forKey: id)
        return result
    }

    private func saveOutput(
        id: UUID,
        destination: OutputDestination,
        date: Date,
    ) throws(OutputError) -> SavedOutput {
        guard var output = outputs[id] else {
            throw .missingOutput
        }

        if let savedURL = output.savedURL {
            if isReachableRegularFile(savedURL) {
                if destination == .configured || destination == .file(savedURL) {
                    return SavedOutput(id: id, url: savedURL, wasAlreadySaved: true)
                }
            } else {
                output.savedURL = nil
                outputs[id] = output
            }
        }

        do {
            let savedURL: URL
            switch destination {
            case .configured:
                guard output.snapshot.isConfiguredDestinationValid else {
                    throw CocoaError(.fileNoSuchFile)
                }
                if output.snapshot.requiresExistingDirectory {
                    var isDirectory: ObjCBool = false
                    let path = output.snapshot.directory.path
                    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
                          isDirectory.boolValue,
                          FileManager.default.isWritableFile(atPath: path)
                    else {
                        throw CocoaError(.fileNoSuchFile)
                    }
                }
                let filename = FilenameFormatter.makeFilename(prefix: output.snapshot.filenamePrefix, date: date)
                savedURL = try saveFile(output.pngData, output.snapshot.directory, filename)
            case let .file(url):
                savedURL = try saveExactFile(output.pngData, url)
            }
            output.savedURL = savedURL
            outputs[id] = output
            return SavedOutput(id: id, url: savedURL, wasAlreadySaved: false)
        } catch {
            throw .saveFailed(String(describing: error))
        }
    }

    private func isReachableRegularFile(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isReadableKey]) else {
            return false
        }
        return values.isRegularFile == true && values.isReadable == true
    }

    func finish(id: UUID) {
        outputs.removeValue(forKey: id)
    }

    func discard(id: UUID) throws(OutputError) {
        guard let output = outputs[id] else { return }
        if let savedURL = output.savedURL {
            do {
                try deleteFile(savedURL)
            } catch {
                throw .deleteFailed(String(describing: error))
            }
        }
        outputs.removeValue(forKey: id)
    }

    func pendingCount() -> Int {
        outputs.count
    }

    func isSaved(id: UUID) -> Bool {
        outputs[id]?.savedURL != nil
    }
}

@MainActor
final class OutputCoordinator {
    typealias ClipboardCopy = @MainActor @Sendable (Data) async throws -> Void
    typealias Sleep = @Sendable (Duration) async throws -> Void

    private let settings: SettingsStore
    private let dateProvider: @Sendable () -> Date
    private let clipboardCopy: ClipboardCopy
    private let sleeper: Sleep
    private var onSave: ((UUID, URL) -> Void)?
    private var onScheduledSaveFailure: ((UUID, OutputError) -> Void)?
    private let store: OutputStore
    private var scheduledTasks: [UUID: Task<Void, Never>] = [:]

    init(
        settings: SettingsStore,
        dateProvider: @escaping @Sendable () -> Date = Date.init,
        clipboardCopy: @escaping ClipboardCopy = { try await ClipboardService.copy(pngData: $0) },
        sleeper: @escaping Sleep = { duration in try await Task.sleep(for: duration) },
        onSave: ((UUID, URL) -> Void)? = nil,
        onScheduledSaveFailure: ((UUID, OutputError) -> Void)? = nil,
        store: OutputStore = OutputStore(),
    ) {
        self.settings = settings
        self.dateProvider = dateProvider
        self.clipboardCopy = clipboardCopy
        self.sleeper = sleeper
        self.onSave = onSave
        self.onScheduledSaveFailure = onScheduledSaveFailure
        self.store = store
    }

    func begin(pngData: Data, scheduleSave: Bool = true) async -> UUID {
        let snapshot = OutputSettingsSnapshot(settings: settings)
        let id = UUID()
        await store.insert(id: id, pngData: pngData, snapshot: snapshot)

        if snapshot.autoCopyToClipboard {
            do {
                try await clipboardCopy(pngData)
            } catch {
                AppLog.output.error("Failed to copy screenshot to the clipboard: \(String(describing: error), privacy: .private)")
                AccessibilityAnnouncer.announce("Screenshot could not be copied to the clipboard")
            }
        }

        if scheduleSave {
            scheduleSaveTask(id: id, delay: snapshot.saveDelaySeconds)
        }
        return id
    }

    func finalize(
        id: UUID,
        destination: OutputDestination = .configured,
    ) async throws(OutputError) -> SavedOutput {
        cancelScheduledSave(id: id)
        let signpostID = AppSignpost.begin("File save")
        defer { AppSignpost.end("File save", id: signpostID) }

        do {
            let result = try await store.save(id: id, destination: destination, date: dateProvider())
            if !result.wasAlreadySaved {
                onSave?(id, result.url)
            }
            return result
        } catch {
            log(error)
            throw error
        }
    }

    func finish(id: UUID) async {
        cancelScheduledSave(id: id)
        await store.finish(id: id)
    }

    func saveAndFinish(
        id: UUID,
        destination: OutputDestination = .configured,
    ) async throws(OutputError) -> SavedOutput {
        cancelScheduledSave(id: id)
        let signpostID = AppSignpost.begin("File save")
        defer { AppSignpost.end("File save", id: signpostID) }

        do {
            let result = try await store.saveAndFinish(id: id, destination: destination, date: dateProvider())
            if !result.wasAlreadySaved {
                onSave?(id, result.url)
            }
            return result
        } catch {
            log(error)
            throw error
        }
    }

    func copy(id: UUID) async throws {
        let data = try await store.pngData(id: id)
        try await clipboardCopy(data)
    }

    func copy(pngData: Data) async throws {
        try await clipboardCopy(pngData)
    }

    func discard(id: UUID) async throws(OutputError) {
        cancelScheduledSave(id: id)
        do {
            try await store.discard(id: id)
        } catch {
            log(error)
            throw error
        }
    }

    func pendingOutputCountForTesting() async -> Int {
        await store.pendingCount()
    }

    func isSaved(id: UUID) async -> Bool {
        await store.isSaved(id: id)
    }

    func setScheduledSaveFailureHandler(_ handler: @escaping (UUID, OutputError) -> Void) {
        onScheduledSaveFailure = handler
    }

    func setSaveHandler(_ handler: @escaping (UUID, URL) -> Void) {
        onSave = handler
    }

    private func scheduleSaveTask(id: UUID, delay: Double) {
        let duration = Duration.seconds(max(delay, 0))
        scheduledTasks[id] = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                if duration > .zero {
                    try await sleeper(duration)
                }
                try Task.checkCancellation()
                let result = try await store.save(id: id, destination: .configured, date: dateProvider())
                if !result.wasAlreadySaved {
                    onSave?(id, result.url)
                }
            } catch is CancellationError {
                return
            } catch let error as OutputError {
                log(error)
                onScheduledSaveFailure?(id, error)
            } catch {
                let outputError = OutputError.saveFailed(String(describing: error))
                log(outputError)
                onScheduledSaveFailure?(id, outputError)
            }
            scheduledTasks.removeValue(forKey: id)
        }
    }

    private func cancelScheduledSave(id: UUID) {
        scheduledTasks.removeValue(forKey: id)?.cancel()
    }

    private func log(_ error: OutputError) {
        AppLog.output.error("Output operation failed: \(error.failureReason ?? error.localizedDescription, privacy: .private)")
        AccessibilityAnnouncer.announce(error.localizedDescription)
    }
}

struct OutputSettingsSnapshot: Sendable {
    let autoCopyToClipboard: Bool
    let saveDelaySeconds: Double
    let directory: URL
    let filenamePrefix: String
    let requiresExistingDirectory: Bool
    let isConfiguredDestinationValid: Bool

    @MainActor
    init(settings: SettingsStore) {
        autoCopyToClipboard = settings.autoCopyToClipboard
        saveDelaySeconds = settings.saveDelaySeconds
        if settings.saveLocationOption == .custom {
            if let customDirectory = SaveLocationResolver.customDirectory(path: settings.customSavePath) {
                directory = customDirectory
                isConfiguredDestinationValid = true
            } else {
                directory = SaveLocationResolver.resolve(option: .downloads, customPath: "")
                isConfiguredDestinationValid = false
            }
        } else {
            directory = SaveLocationResolver.resolve(
                option: settings.saveLocationOption,
                customPath: settings.customSavePath,
            )
            isConfiguredDestinationValid = true
        }
        filenamePrefix = settings.filenamePrefix
        requiresExistingDirectory = settings.saveLocationOption == .custom
    }
}
