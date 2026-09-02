import Testing
@testable import iWheelCore

@Suite struct HotkeyRepairTests {
    @Test func repairEnablesMissingHotkeys() {
        let (root, changed) = HotkeyRepair.repaired(root: [:], desktopCount: 3)
        #expect(changed)
        for desktop in 1...3 {
            let entry = root[String(HotkeyRepair.baseID + desktop - 1)] as? [String: Any]
            #expect(entry?["enabled"] as? Bool == true)
        }
        // Desktop 1 gets ctrl+1 (keycode 18).
        let value = (root["118"] as? [String: Any])?["value"] as? [String: Any]
        #expect(value?["parameters"] as? [Int] == [65535, 18, 262144])
    }

    @Test func repairEnablesDisabledHotkey() {
        let disabled: [String: Any] = ["118": ["enabled": false, "value": ["type": "standard", "parameters": [65535, 18, 262144]]]]
        let (root, changed) = HotkeyRepair.repaired(root: disabled, desktopCount: 1)
        #expect(changed)
        #expect((root["118"] as? [String: Any])?["enabled"] as? Bool == true)
    }

    @Test func repairLeavesEnabledEntriesUntouched() {
        // A user-customized binding must survive the repair.
        let custom: [String: Any] = ["118": ["enabled": true, "value": ["type": "standard", "parameters": [65535, 122, 1048576]]]]
        let (root, changed) = HotkeyRepair.repaired(root: custom, desktopCount: 1)
        #expect(!changed)
        let params = ((root["118"] as? [String: Any])?["value"] as? [String: Any])?["parameters"] as? [Int]
        #expect(params == [65535, 122, 1048576])
    }

    @Test func repairCapsAtTenDesktops() {
        let (root, _) = HotkeyRepair.repaired(root: [:], desktopCount: 15)
        #expect(root[String(HotkeyRepair.baseID + 9)] != nil)  // desktop 10
        #expect(root[String(HotkeyRepair.baseID + 10)] == nil) // desktop 11: no default combo
    }

    @Test func bindingReadsEnabledEntry() {
        let root: [String: Any] = ["119": ["enabled": true, "value": ["type": "standard", "parameters": [65535, 19, 262144]]]]
        let binding = HotkeyRepair.binding(in: root, desktop: 2)
        #expect(binding == HotkeyRepair.Binding(keycode: 19, modifiers: 262144))
    }

    @Test func bindingNilWhenDisabledOrMissing() {
        let root: [String: Any] = ["118": ["enabled": false, "value": ["type": "standard", "parameters": [65535, 18, 262144]]]]
        #expect(HotkeyRepair.binding(in: root, desktop: 1) == nil)
        #expect(HotkeyRepair.binding(in: root, desktop: 5) == nil)
    }

    @Test func zeroDesktopsIsNoOp() {
        let (root, changed) = HotkeyRepair.repaired(root: [:], desktopCount: 0)
        #expect(root.isEmpty)
        #expect(!changed)
    }
}
