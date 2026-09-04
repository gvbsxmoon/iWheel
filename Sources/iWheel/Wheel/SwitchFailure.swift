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
    /// viaDirectJump: the switch used "Switch to Desktop N"; otherwise it
    /// hopped with "Move left/right a space". The message names the
    /// shortcut that actually failed.
    case switchDidNotHappen(target: SpaceInfo, viaDirectJump: Bool)

    var message: String {
        switch self {
        case .accessibilityMissing:
            return "iWheel needs the Accessibility permission to switch spaces. Grant it in the window that just opened, then try again."
        case .switchDidNotHappen(let target, let viaDirectJump):
            let shortcut = viaDirectJump
                ? "\"Switch to Desktop \(target.desktopNumber ?? 1)\""
                : "\"Move left a space\" and \"Move right a space\""
            return "The switch did not happen. Open System Settings > Keyboard > Keyboard Shortcuts > Mission Control and turn on \(shortcut), then try again."
        }
    }

    var pane: SettingsPane? {
        switch self {
        case .accessibilityMissing: return .accessibility
        case .switchDidNotHappen: return .keyboard
        }
    }
}
