import AppKit
import Combine
import ServiceManagement

@MainActor
final class SettingsStore: ObservableObject {
    enum HapticStyle: String, CaseIterable, Identifiable {
        case off, light, strong
        var id: String { rawValue }
    }

    @Published var ringRadius: Double { didSet { save() } }
    @Published var zoomScale: Double { didSet { save() } }
    @Published var hysteresisDegrees: Double { didSet { save() } }
    @Published var deadZone: Double { didSet { save() } }
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
        // 120 is the new default; migrate values saved when 180 was the default.
        let storedRadius = defaults.object(forKey: "ringRadius") as? Double
        ringRadius = (storedRadius == nil || storedRadius == 180) ? 120 : min(storedRadius!, 240)
        // 2.0 is the new default; migrate values saved when 1.5 was the default.
        let storedZoom = defaults.object(forKey: "zoomScale") as? Double
        zoomScale = (storedZoom == nil || storedZoom == 1.5) ? 2.0 : storedZoom!
        hysteresisDegrees = defaults.object(forKey: "hysteresisDegrees") as? Double ?? 4
        // 0.03 / 0.15 are the new defaults; migrate values saved under the old ones.
        let storedDeadZone = defaults.object(forKey: "deadZone") as? Double
        deadZone = (storedDeadZone == nil || storedDeadZone == 0.08) ? 0.03 : storedDeadZone!
        let storedHold = defaults.object(forKey: "holdSeconds") as? Double
        holdSeconds = (storedHold == nil || storedHold == 0.35) ? 0.15 : storedHold!
        hapticStyle = HapticStyle(rawValue: defaults.string(forKey: "hapticStyle") ?? "") ?? .strong
        launchAtLogin = SMAppService.mainApp.status == .enabled
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
        defaults.set(ringRadius, forKey: "ringRadius")
        defaults.set(zoomScale, forKey: "zoomScale")
        defaults.set(hysteresisDegrees, forKey: "hysteresisDegrees")
        defaults.set(deadZone, forKey: "deadZone")
        defaults.set(holdSeconds, forKey: "holdSeconds")
        defaults.set(hapticStyle.rawValue, forKey: "hapticStyle")
    }
}
