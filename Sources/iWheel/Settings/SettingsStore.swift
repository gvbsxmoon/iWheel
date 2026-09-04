import AppKit
import Combine
import ServiceManagement

@MainActor
final class SettingsStore: ObservableObject {
    enum HapticStyle: String, CaseIterable, Identifiable {
        case off, light, strong
        var id: String { rawValue }
    }

    @Published var dockSpacing: Double { didSet { save() } }
    /// Percent of trackpad travel that slides through all spaces (dock).
    @Published var dockSpan: Double { didSet { save() } }
    /// How many fingers navigate while the switcher is open (2 or 3).
    @Published var navFingers: Int { didSet { save() } }
    @Published var cardWidth: Double { didSet { save() } }
    /// Virtual key code + Carbon modifier flags of the open shortcut.
    @Published var hotkeyKeyCode: Int { didSet { save(); hotkeyChanged?() } }
    @Published var hotkeyModifiers: Int { didSet { save(); hotkeyChanged?() } }
    @Published var hotkeyDisplay: String { didSet { save() } }
    /// Set by the AppDelegate to re-register the Carbon hotkey on change.
    var hotkeyChanged: (() -> Void)?

    @Published var zoomScale: Double { didSet { save() } }
    @Published var holdSeconds: Double { didSet { save() } }
    @Published var hapticStyle: HapticStyle { didSet { save() } }
    /// Mirrors SMAppService registration. Only effective when running from
    /// the .app bundle - a bare `swift run` binary cannot register.
    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("iWheel: launch-at-login change failed: \(error.localizedDescription)")
                launchAtLogin = oldValue
            }
        }
    }

    private let defaults = UserDefaults.standard

    init() {
        // 2.0 is the new default; migrate values saved when 1.5 was the default.
        let storedZoom = defaults.object(forKey: "zoomScale") as? Double
        zoomScale = (storedZoom == nil || storedZoom == 1.5) ? 2.0 : storedZoom!
        // 0.15 is the new default; migrate values saved under the old one.
        let storedHold = defaults.object(forKey: "holdSeconds") as? Double
        holdSeconds = (storedHold == nil || storedHold == 0.35) ? 0.15 : storedHold!
        hapticStyle = HapticStyle(rawValue: defaults.string(forKey: "hapticStyle") ?? "") ?? .strong
        // 150 / 120 / 25 are the new defaults; migrate values saved under the
        // previous defaults and clamp spacing into the 100...220 range.
        let storedSpacing = defaults.object(forKey: "dockSpacing") as? Double
        dockSpacing = (storedSpacing == nil || storedSpacing == 84 || storedSpacing == 120) ? 150 : min(max(storedSpacing!, 100), 220)
        let storedCard = defaults.object(forKey: "cardWidth") as? Double
        cardWidth = (storedCard == nil || storedCard == 68 || storedCard == 100) ? 120 : storedCard!
        let storedSpan = defaults.object(forKey: "dockSpan") as? Double
        dockSpan = (storedSpan == nil || storedSpan == 35) ? 25 : storedSpan!
        navFingers = defaults.object(forKey: "navFingers") as? Int ?? 3
        // Default shortcut: ctrl+option+cmd+W. 13 = kVK_ANSI_W,
        // 6400 = cmdKey(256) | optionKey(2048) | controlKey(4096).
        hotkeyKeyCode = defaults.object(forKey: "hotkeyKeyCode") as? Int ?? 13
        hotkeyModifiers = defaults.object(forKey: "hotkeyModifiers") as? Int ?? 6400
        hotkeyDisplay = defaults.string(forKey: "hotkeyDisplay") ?? "⌃⌥⌘W"
        launchAtLogin = SMAppService.mainApp.status == .enabled

        // Keys retired with the ring layout.
        for stale in ["layout", "ringRadius", "hysteresisDegrees", "deadZone"] {
            defaults.removeObject(forKey: stale)
        }
    }

    func performHaptic() {
        switch hapticStyle {
        case .off:
            return
        case .light:
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        case .strong:
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        }
    }

    private func save() {
        defaults.set(zoomScale, forKey: "zoomScale")
        defaults.set(holdSeconds, forKey: "holdSeconds")
        defaults.set(hapticStyle.rawValue, forKey: "hapticStyle")
        defaults.set(dockSpacing, forKey: "dockSpacing")
        defaults.set(dockSpan, forKey: "dockSpan")
        defaults.set(navFingers, forKey: "navFingers")
        defaults.set(cardWidth, forKey: "cardWidth")
        defaults.set(hotkeyKeyCode, forKey: "hotkeyKeyCode")
        defaults.set(hotkeyModifiers, forKey: "hotkeyModifiers")
        defaults.set(hotkeyDisplay, forKey: "hotkeyDisplay")
    }
}
