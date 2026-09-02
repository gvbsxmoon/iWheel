import CoreGraphics
import iWheelCore

/// Switches desktop by posting the Mission Control "Switch to Desktop N"
/// shortcut. Reads the ACTUAL configured binding from the symbolic hotkeys
/// (honoring user customizations) and can enable missing ones natively.
/// Capped at 10 desktops - beyond that there is no default combination.
/// v2 option for more: private SLSManagedDisplaySetCurrentSpace.
final class SpaceSwitcher {
    private let hotkeys = SymbolicHotkeys()
    private let digitKeycodes = HotkeyRepair.digitKeycodes.map { CGKeyCode($0) }

    var maxReachableIndex: Int { digitKeycodes.count }

    /// Called when the wheel opens: repairs disabled hotkeys so the commit
    /// that follows actually lands. Cheap no-op when everything is enabled.
    func prepare(desktopCount: Int) {
        hotkeys.ensureEnabled(desktopCount: desktopCount)
    }

    func switchTo(index: Int) { // 1-based desktop index
        guard index >= 1 && index <= digitKeycodes.count else { return }

        let keycode: CGKeyCode
        let flags: CGEventFlags
        if let binding = hotkeys.binding(forDesktop: index) {
            keycode = binding.keycode
            flags = binding.flags
        } else {
            keycode = digitKeycodes[index - 1]
            flags = .maskControl
        }

        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: keycode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keycode, keyDown: false)
        down?.flags = flags
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
