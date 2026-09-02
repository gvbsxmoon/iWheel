import Foundation

/// Pure dictionary transforms for the com.apple.symbolichotkeys domain.
/// ID 118 is "Switch to Desktop 1"; following desktops are sequential.
public enum HotkeyRepair {
    public static let baseID = 118
    /// ANSI keycodes for digits 1..9, then 0.
    public static let digitKeycodes: [Int] = [18, 19, 20, 21, 23, 22, 26, 28, 25, 29]
    public static let controlModifier = 262144
    public static let noCharacter = 65535

    public struct Binding: Equatable {
        public let keycode: Int
        public let modifiers: Int
        public init(keycode: Int, modifiers: Int) {
            self.keycode = keycode
            self.modifiers = modifiers
        }
    }

    /// The binding actually configured for a desktop, honoring user
    /// customizations. nil when missing or disabled.
    public static func binding(in root: [String: Any], desktop: Int) -> Binding? {
        guard let entry = root[String(baseID + desktop - 1)] as? [String: Any],
              (entry["enabled"] as? Bool) == true,
              let value = entry["value"] as? [String: Any],
              let params = value["parameters"] as? [Int],
              params.count >= 3 else { return nil }
        return Binding(keycode: params[1], modifiers: params[2])
    }

    /// Enables missing or disabled hotkeys for desktops 1..count with the
    /// default ctrl+digit binding. Enabled entries are left untouched.
    /// Beyond 10 there is no default combination, so those are skipped.
    public static func repaired(root: [String: Any], desktopCount: Int) -> (root: [String: Any], changed: Bool) {
        guard desktopCount >= 1 else { return (root, false) }
        var out = root
        var changed = false

        for desktop in 1...min(desktopCount, digitKeycodes.count) {
            let id = String(baseID + desktop - 1)
            if ((out[id] as? [String: Any])?["enabled"] as? Bool) == true { continue }
            out[id] = [
                "enabled": true,
                "value": [
                    "type": "standard",
                    "parameters": [noCharacter, digitKeycodes[desktop - 1], controlModifier],
                ],
            ]
            changed = true
        }
        return (out, changed)
    }
}
