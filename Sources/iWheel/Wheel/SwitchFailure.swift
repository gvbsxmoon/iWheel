import AppKit

/// Deep links into the exact System Settings pane a fix lives in.
enum SettingsPane: String {
    case accessibility = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    case inputMonitoring = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
    case screenRecording = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    case keyboard = "x-apple.systempreferences:com.apple.Keyboard-Settings.extension"

    func open() {
        guard let url = URL(string: rawValue) else { return }
        NSWorkspace.shared.open(url)
    }
}

/// Everything that can stop a space switch, with a message a non-technical
/// user can act on. One failure, one sentence, one place to fix it.
enum SwitchFailure {
    case accessibilityMissing
    case beyondReach(index: Int, max: Int)
    case switchDidNotHappen(index: Int)

    var message: String {
        switch self {
        case .accessibilityMissing:
            return "iWheel needs the Accessibility permission to switch spaces. Grant it in the window that just opened, then try again."
        case .beyondReach(let index, let max):
            return "Space \(index) is out of reach: macOS keyboard shortcuts stop at space \(max), so iWheel supports up to \(max) spaces."
        case .switchDidNotHappen(let index):
            return "The switch did not happen. Open System Settings > Keyboard > Keyboard Shortcuts > Mission Control and turn on \"Switch to Desktop \(index)\", then try again."
        }
    }

    var pane: SettingsPane? {
        switch self {
        case .accessibilityMissing: return .accessibility
        case .beyondReach: return nil
        case .switchDidNotHappen: return .keyboard
        }
    }
}
