import AppKit
import Foundation

final class AppSettings {

    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let opacity = "GlassPlayer.opacity"
        static let alwaysOnTop = "GlassPlayer.alwaysOnTop"
        static let clickThrough = "GlassPlayer.clickThrough"
        static let windowFrame = "GlassPlayer.windowFrame"
    }

    private enum LegacyKey {
        static let opacity = "windowOpacity"
        static let alwaysOnTop = "alwaysOnTop"
        static let clickThrough = "clickThrough"
        static let windowFrame = "windowFrame"
    }

    private init() {
        migrateIfNeeded()
    }

    // MARK: - Properties

    var opacity: Float {
        get {
            guard defaults.object(forKey: Key.opacity) != nil else { return 1.0 }
            return min(max(defaults.float(forKey: Key.opacity), 0.1), 1.0)
        }
        set { defaults.set(newValue, forKey: Key.opacity) }
    }

    var alwaysOnTop: Bool {
        get { defaults.bool(forKey: Key.alwaysOnTop) }
        set { defaults.set(newValue, forKey: Key.alwaysOnTop) }
    }

    var clickThrough: Bool {
        get { defaults.bool(forKey: Key.clickThrough) }
        set { defaults.set(newValue, forKey: Key.clickThrough) }
    }

    var windowFrame: NSRect? {
        get {
            guard let data = defaults.data(forKey: Key.windowFrame) else { return nil }
            guard let frame = try? JSONDecoder().decode(CodableRect.self, from: data) else { return nil }
            let rect = frame.toNSRect()
            guard rect.width >= 320, rect.height >= 200 else { return nil }
            let onScreen = NSScreen.screens.contains { $0.visibleFrame.intersects(rect) }
            guard onScreen else { return nil }
            return rect
        }
        set {
            guard let rect = newValue else {
                defaults.removeObject(forKey: Key.windowFrame)
                return
            }
            let codable = CodableRect(from: rect)
            if let data = try? JSONEncoder().encode(codable) {
                defaults.set(data, forKey: Key.windowFrame)
            }
        }
    }

    // MARK: - Migration

    private func migrateIfNeeded() {
        guard !defaults.bool(forKey: "GlassPlayer.migrated") else { return }

        if defaults.object(forKey: LegacyKey.opacity) != nil {
            defaults.set(defaults.float(forKey: LegacyKey.opacity), forKey: Key.opacity)
            defaults.removeObject(forKey: LegacyKey.opacity)
        }
        if defaults.object(forKey: LegacyKey.alwaysOnTop) != nil {
            defaults.set(defaults.bool(forKey: LegacyKey.alwaysOnTop), forKey: Key.alwaysOnTop)
            defaults.removeObject(forKey: LegacyKey.alwaysOnTop)
        }
        if defaults.object(forKey: LegacyKey.clickThrough) != nil {
            defaults.set(defaults.bool(forKey: LegacyKey.clickThrough), forKey: Key.clickThrough)
            defaults.removeObject(forKey: LegacyKey.clickThrough)
        }
        if let frameStr = defaults.string(forKey: LegacyKey.windowFrame) {
            let rect = NSRectFromString(frameStr)
            if rect.width >= 320, rect.height >= 200 {
                let codable = CodableRect(from: rect)
                if let data = try? JSONEncoder().encode(codable) {
                    defaults.set(data, forKey: Key.windowFrame)
                }
            }
            defaults.removeObject(forKey: LegacyKey.windowFrame)
        }

        defaults.set(true, forKey: "GlassPlayer.migrated")
    }
}

// MARK: - Codable Frame

private struct CodableRect: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(from rect: NSRect) {
        x = Double(rect.origin.x)
        y = Double(rect.origin.y)
        width = Double(rect.size.width)
        height = Double(rect.size.height)
    }

    func toNSRect() -> NSRect {
        NSRect(x: x, y: y, width: width, height: height)
    }
}
