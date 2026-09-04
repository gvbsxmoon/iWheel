import CoreGraphics
import Foundation
import iWheelCore

/// CFPreferences boundary around HotkeyRepair (the pure, tested logic).
/// On new Macs the "Switch to Desktop N" hotkeys exist but are DISABLED by
/// default, which silently breaks ctrl+N switching.
final class SymbolicHotkeys {
    private let domain = "com.apple.symbolichotkeys"
    private let rootKey = "AppleSymbolicHotKeys"

    struct Binding {
        let keycode: CGKeyCode
        let flags: CGEventFlags
    }

    /// The binding actually configured for a desktop, honoring user customizations.
    func binding(forDesktop index: Int) -> Binding? {
        guard let b = HotkeyRepair.binding(in: readRoot(), desktop: index) else { return nil }
        return Binding(keycode: CGKeyCode(b.keycode), flags: CGEventFlags(rawValue: UInt64(b.modifiers)))
    }

    /// The configured "move a space" binding, honoring user customizations.
    func moveBinding(right: Bool) -> Binding? {
        guard let b = HotkeyRepair.moveBinding(in: readRoot(), right: right) else { return nil }
        return Binding(keycode: CGKeyCode(b.keycode), flags: CGEventFlags(rawValue: UInt64(b.modifiers)))
    }

    /// Enables missing or disabled hotkeys for desktops 1..count natively,
    /// then reloads settings. Cheap no-op when everything is enabled.
    @discardableResult
    func ensureEnabled(desktopCount: Int) -> Bool {
        let root = readRoot()
        // A transient read failure returns [:]; writing on that base would
        // replace the whole domain and wipe every other symbolic hotkey the
        // user configured. Real systems always have entries here.
        guard !root.isEmpty else {
            NSLog("iWheel: symbolichotkeys read came back empty - skipping repair")
            return false
        }
        let (repairedRoot, changed) = HotkeyRepair.repaired(root: root, desktopCount: desktopCount)
        if changed {
            CFPreferencesSetAppValue(rootKey as CFString, repairedRoot as CFDictionary, domain as CFString)
            CFPreferencesAppSynchronize(domain as CFString)
            // Off-main: reload() blocks on a subprocess, and this runs on
            // the wheel-open hot path.
            Task.detached(priority: .utility) { SettingsActivator.reload() }
            NSLog("iWheel: enabled missing Switch-to-Desktop hotkeys")
        }
        return changed
    }

    private func readRoot() -> [String: Any] {
        CFPreferencesCopyAppValue(rootKey as CFString, domain as CFString) as? [String: Any] ?? [:]
    }
}

/// Applies preference changes live through the same private reload that
/// System Settings triggers. Without it, gesture and hotkey prefs are only
/// re-read at login - a Dock restart alone is not enough on recent macOS.
enum SettingsActivator {
    static func reload() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings")
        process.arguments = ["-u"]
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            NSLog("iWheel: activateSettings failed: \(error.localizedDescription)")
        }
    }
}
