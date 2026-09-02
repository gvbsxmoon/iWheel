import AppKit
import CoreGraphics

/// Swallows pointer events while the wheel is latched open, so single-finger
/// scrubbing does not move the cursor or click through the overlay.
/// A physical click while active is reported as a commit gesture.
final class PointerEventBlocker {
    var onSwallowedClick: (() -> Void)?
    /// Tab / shift+Tab while the wheel is open steps the selection.
    var onTab: ((_ backwards: Bool) -> Void)?

    static let tabKeycode: Int64 = 48 // physical Tab position, layout-independent

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    fileprivate func reenable() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func enable() {
        guard tap == nil else { return }
        let mask: CGEventMask =
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.rightMouseUp.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue) |
            (1 << CGEventType.keyDown.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let blocker = Unmanaged<PointerEventBlocker>.fromOpaque(refcon).takeUnretainedValue()
            // The system disables a tap it considers slow or user-disruptive;
            // re-enable, or the wheel silently stops swallowing input.
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                DispatchQueue.main.async { blocker.reenable() }
                return Unmanaged.passUnretained(event)
            }
            if type == .keyDown {
                // The keycode is inspected only to catch Tab and is never
                // stored, logged, or transmitted. Every other key passes
                // through untouched.
                let keycode = event.getIntegerValueField(.keyboardEventKeycode)
                guard keycode == PointerEventBlocker.tabKeycode else { return Unmanaged.passUnretained(event) }
                let backwards = event.flags.contains(.maskShift)
                DispatchQueue.main.async { blocker.onTab?(backwards) }
                return nil
            }
            if type == .leftMouseDown {
                DispatchQueue.main.async { blocker.onSwallowedClick?() }
            }
            return nil
        }

        guard let created = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            NSLog("iWheel: could not create event tap (missing Accessibility permission?)")
            return
        }
        tap = created
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
    }

    func disable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
    }
}
