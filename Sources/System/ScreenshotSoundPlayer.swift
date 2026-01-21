import AppKit

protocol SoundResourceBundle {
    func url(forResource name: String?, withExtension ext: String?) -> URL?
}

extension Bundle: SoundResourceBundle {}

enum ScreenshotSoundPlayer {
    private static let soundExtension = "wav"
    private static var soundCache: [String: NSSound] = [:]

    static func play(sound option: ShutterSoundOption, volume: Double, isEnabled: Bool) {
        guard isEnabled else { return }
        let name = option.resourceName
        guard let sound = sound(named: name) else {
            NSLog("Screenshot sound missing: \(name).\(soundExtension)")
            return
        }
        sound.stop()
        sound.currentTime = 0
        sound.volume = clampVolume(volume)
        sound.play()
    }

    static func resolveSoundURL(
        soundName: String,
        soundExtension: String,
        bundles: [SoundResourceBundle],
    ) -> URL? {
        for bundle in bundles {
            if let url = bundle.url(forResource: soundName, withExtension: soundExtension) {
                return url
            }
        }
        return nil
    }

    private static func sound(named name: String) -> NSSound? {
        if let cached = soundCache[name] {
            return cached
        }

        guard let url = soundURL(named: name) else { return nil }
        let sound = NSSound(contentsOf: url, byReference: false)
        soundCache[name] = sound
        return sound
    }

    private static func soundURL(named name: String) -> URL? {
        var bundles: [SoundResourceBundle] = [
            Bundle.main,
            Bundle(for: BundleMarker.self),
        ]
        #if SWIFT_PACKAGE
            bundles.append(Bundle.module)
        #endif
        return resolveSoundURL(soundName: name, soundExtension: soundExtension, bundles: bundles)
    }

    private static func clampVolume(_ volume: Double) -> Float {
        let clamped = min(max(volume, 0), 1)
        return Float(clamped)
    }

    private final class BundleMarker {}
}
