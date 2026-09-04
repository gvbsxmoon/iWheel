import CoreGraphics
import iWheelCore

/// Switches space by posting Mission Control shortcuts, reading the ACTUAL
/// configured bindings from the symbolic hotkeys (honoring user
/// customizations) and enabling missing ones natively.
/// - Numbered desktops 1...10: "Switch to Desktop N", one direct jump.
/// - Fullscreen apps and desktops past 10: "Move left/right a space",
///   one hop per step. macOS chains rapid hops into a continuous slide.
final class SpaceSwitcher {
    private let hotkeys = SymbolicHotkeys()
    private let digitKeycodes = HotkeyRepair.digitKeycodes.map { CGKeyCode($0) }
    /// Close enough that macOS coalesces the slides, far enough apart
    /// that no hop is dropped.
    private static let hopIntervalNs: UInt64 = 60_000_000

    var maxDirectIndex: Int { digitKeycodes.count }

    /// Called when the wheel opens: repairs disabled hotkeys so the commit
    /// that follows actually lands. Cheap no-op when everything is enabled.
    func prepare(desktopCount: Int) {
        hotkeys.ensureEnabled(desktopCount: desktopCount)
    }

    func switchTo(index: Int) { // 1-based desktop number
        guard index >= 1 && index <= digitKeycodes.count else { return }

        if let binding = hotkeys.binding(forDesktop: index) {
            post(keycode: binding.keycode, flags: binding.flags)
        } else {
            post(keycode: digitKeycodes[index - 1], flags: .maskControl)
        }
    }

    /// Fires |steps| move-a-space hops (negative = left).
    func move(steps: Int) async {
        guard steps != 0 else { return }
        let right = steps > 0
        let binding = hotkeys.moveBinding(right: right)
        let keycode = binding?.keycode ?? CGKeyCode(right ? HotkeyRepair.rightArrowKeycode : HotkeyRepair.leftArrowKeycode)
        var flags = binding?.flags ?? .maskControl
        // Hardware arrow keys carry the fn and numeric-pad flags; the
        // symbolic hotkey system ignores synthetic arrows without them.
        if (123...126).contains(keycode) {
            flags.insert(.maskSecondaryFn)
            flags.insert(.maskNumericPad)
        }

        for hop in 0..<abs(steps) {
            if hop > 0 { try? await Task.sleep(nanoseconds: Self.hopIntervalNs) }
            post(keycode: keycode, flags: flags)
        }
    }

    private func post(keycode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: keycode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keycode, keyDown: false)
        down?.flags = flags
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
