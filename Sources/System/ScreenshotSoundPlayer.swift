import AppKit

protocol SoundResourceBundle {
    func url(forResource name: String?, withExtension ext: String?) -> URL?
}

extension Bundle: SoundResourceBundle {}

enum ScreenshotSoundPlayer {
    private static let soundName = "shutter"
    private static let soundExtension = "wav"

    private static let soundURL: URL? = {
        var bundles: [SoundResourceBundle] = [
            Bundle.main,
            Bundle(for: BundleMarker.self),
        ]
        #if SWIFT_PACKAGE
            bundles.append(Bundle.module)
        #endif
        return resolveSoundURL(bundles: bundles)
    }()

    private static let sound: NSSound? = {
        guard let url = soundURL else { return nil }
        let sound = NSSound(contentsOf: url, byReference: false)
        sound?.volume = 1.0
        return sound
    }()

    static func play() {
        guard let sound else {
            NSLog("Screenshot sound missing: \(soundName).\(soundExtension)")
            return
        }
        sound.stop()
        sound.currentTime = 0
        sound.play()
    }

    static func resolveSoundURL(bundles: [SoundResourceBundle]) -> URL? {
        for bundle in bundles {
            if let url = bundle.url(forResource: soundName, withExtension: soundExtension) {
                return url
            }
        }
        return nil
    }

    private final class BundleMarker {}
}
