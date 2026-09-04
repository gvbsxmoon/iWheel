import Foundation

/// Pure dictionary transforms for the com.apple.symbolichotkeys domain.
/// ID 118 is "Switch to Desktop 1"; following desktops are sequential.
public enum HotkeyRepair {
    public static let baseID = 118
    /// "Move left a space" / "Move right a space" symbolic hotkey ids.
    /// They reach what ctrl+digit cannot: fullscreen apps and desktops
    /// past 10, one hop at a time.
    public static let moveLeftID = 79
    public static let moveRightID = 81
    /// ANSI keycodes for digits 1..9, then 0.
    public static let digitKeycodes: [Int] = [18, 19, 20, 21, 23, 22, 26, 28, 25, 29]
    public static let leftArrowKeycode = 123
    public static let rightArrowKeycode = 124
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
        enabledBinding(root[String(baseID + desktop - 1)])
    }

    /// The configured "move a space" binding. nil when missing or disabled.
    public static func moveBinding(in root: [String: Any], right: Bool) -> Binding? {
        enabledBinding(root[String(right ? moveRightID : moveLeftID)])
    }

    private static func enabledBinding(_ rawEntry: Any?) -> Binding? {
        guard let entry = rawEntry as? [String: Any],
              (entry["enabled"] as? Bool) == true,
              let value = entry["value"] as? [String: Any],
              let params = value["parameters"] as? [Int],
              params.count >= 3 else { return nil }
        return Binding(keycode: params[1], modifiers: params[2])
    }

    /// Enables missing or disabled hotkeys for desktops 1..count and the
    /// two move-a-space shortcuts, with their default ctrl bindings.
    /// Enabled entries are left untouched. Desktops beyond 10 have no
    /// default combination and are skipped (they are reached by moves).
    public static func repaired(root: [String: Any], desktopCount: Int) -> (root: [String: Any], changed: Bool) {
        guard desktopCount >= 1 else { return (root, false) }
        var out = root
        var changed = false

        var wanted: [(id: Int, keycode: Int)] = (1...min(desktopCount, digitKeycodes.count)).map {
            (baseID + $0 - 1, digitKeycodes[$0 - 1])
        }
        wanted.append((moveLeftID, leftArrowKeycode))
        wanted.append((moveRightID, rightArrowKeycode))

        for (id, keycode) in wanted {
            let key = String(id)
            if ((out[key] as? [String: Any])?["enabled"] as? Bool) == true { continue }
            out[key] = [
                "enabled": true,
                "value": [
                    "type": "standard",
                    "parameters": [noCharacter, keycode, controlModifier],
                ],
            ]
            changed = true
        }
        return (out, changed)
    }
}
