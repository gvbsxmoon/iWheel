import Carbon.HIToolbox
import Foundation

/// Global shortcut via Carbon RegisterEventHotKey.
/// Deliberately NOT an always-on event tap: the system delivers only the
/// registered combination, so no other keystroke is ever visible to the
/// app while the wheel is closed - keeping the SECURITY.md promise that
/// the keyboard tap exists only while the overlay is open.
final class GlobalHotkey {
    var onPressed: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    /// Registers (or re-registers) the shortcut. keyCode is a virtual key
    /// code, modifiers are Carbon flags (cmdKey, optionKey, controlKey, shiftKey).
    func apply(keyCode: Int, modifiers: Int) {
        installHandlerIfNeeded()
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        let hotKeyID = EventHotKeyID(signature: OSType(0x6957686C), id: 1) // 'iWhl'
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            NSLog("iWheel: hotkey registration failed (%d)", status)
        }
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let hotkey = Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { hotkey.onPressed?() }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
    }
}
