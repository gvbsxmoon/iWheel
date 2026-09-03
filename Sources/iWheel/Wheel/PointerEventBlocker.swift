import AppKit
import CoreGraphics

/// Swallows pointer events while the wheel is open, so 2-finger pointing
/// does not move the cursor, scroll, or click through the overlay.
/// A physical click while active is reported as a commit gesture.
final class PointerEventBlocker {
    var onSwallowedClick: (() -> Void)?
    /// Tab / shift+Tab while the wheel is open steps the selection.
    var onTab: ((_ backwards: Bool) -> Void)?
    /// Esc while the wheel is open cancels it.
    var onEscape: (() -> Void)?
    /// Return while the wheel is open commits the selection.
    var onReturn: (() -> Void)?

    static let tabKeycode: Int64 = 48    // physical Tab position, layout-independent
    static let escapeKeycode: Int64 = 53 // physical Esc position
    static let returnKeycode: Int64 = 36 // physical Return position

    // Private CGEvent plumbing for system trackpad gestures (Spaces swipe,
    // Mission Control, App Expose). The Dock consumes these as private
    // CGEvents of type 30 (DockControl, paired with type 29 companions), so
    // a filtering tap that returns nil suppresses the gesture BEFORE the
    // Dock acts on it. Field indices are reverse-engineered but stable in
    // practice; the technique is the one proven by joshuarli/iss and
    // mmathys/noswoosh on macOS 26/27. We only ever suppress (never
    // synthesize), which is the simple, durable side of that mechanism.
    private static let gestureEventType: Int64 = 29      // kCGSEventGesture
    private static let dockControlEventType: Int64 = 30  // kCGSEventDockControl
    private static let realTypeField = CGEventField(rawValue: 55)!
    private static let hidTypeField = CGEventField(rawValue: 110)!
    private static let phaseField = CGEventField(rawValue: 132)!
    private static let dockSwipeHIDType: Int64 = 23
    private static let phaseBegan: Int64 = 1
    private static let phaseEnded: Int64 = 4
    private static let phaseCancelled: Int64 = 8

    /// True while a system swipe that BEGAN under our tap is being swallowed.
    /// A gesture already in flight when the wheel opened is passed through,
    /// so the Dock is never left with a half-delivered gesture.
    private var suppressingSwipe = false

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    fileprivate func reenable() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func enable() {
        guard tap == nil else { return }
        // Built imperatively: a single OR chain of mixed-width literals is
        // too much for the type-checker in release builds.
        let tapTypes: [CGEventType] = [
            .mouseMoved, .leftMouseDown, .leftMouseUp, .leftMouseDragged,
            .rightMouseDown, .rightMouseUp, .scrollWheel, .keyDown,
        ]
        var mask: CGEventMask = 0
        for t in tapTypes {
            mask |= CGEventMask(1) << CGEventMask(t.rawValue)
        }
        mask |= CGEventMask(1) << CGEventMask(PointerEventBlocker.gestureEventType)
        mask |= CGEventMask(1) << CGEventMask(PointerEventBlocker.dockControlEventType)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let blocker = Unmanaged<PointerEventBlocker>.fromOpaque(refcon).takeUnretainedValue()
            // The system disables a tap it considers slow or user-disruptive;
            // re-enable, or the wheel silently stops swallowing input.
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                DispatchQueue.main.async { blocker.reenable() }
                return Unmanaged.passUnretained(event)
            }
            // System trackpad gestures (Spaces swipe, Mission Control, App
            // Expose): swallow them while the wheel is open, so the wheel
            // owns the trackpad completely. Only gestures that BEGIN while
            // we are active are suppressed; one already in flight completes
            // natively so the Dock's gesture state stays consistent.
            let rawType = Int64(type.rawValue)
            if rawType == PointerEventBlocker.gestureEventType || rawType == PointerEventBlocker.dockControlEventType {
                let realType = event.getIntegerValueField(PointerEventBlocker.realTypeField)
                if realType == PointerEventBlocker.dockControlEventType,
                   event.getIntegerValueField(PointerEventBlocker.hidTypeField) == PointerEventBlocker.dockSwipeHIDType {
                    let phase = event.getIntegerValueField(PointerEventBlocker.phaseField)
                    if phase == PointerEventBlocker.phaseBegan {
                        blocker.suppressingSwipe = true
                        return nil
                    }
                    guard blocker.suppressingSwipe else { return Unmanaged.passUnretained(event) }
                    if phase == PointerEventBlocker.phaseEnded || phase == PointerEventBlocker.phaseCancelled {
                        blocker.suppressingSwipe = false
                    }
                    return nil
                }
                // Companion gesture events paired with a suppressed swipe.
                if realType == PointerEventBlocker.gestureEventType, blocker.suppressingSwipe {
                    return nil
                }
                return Unmanaged.passUnretained(event)
            }
            if type == .keyDown {
                // Key codes are inspected only to catch Tab and Esc and are
                // never stored, logged, or transmitted. Every other key
                // passes through untouched.
                let keycode = event.getIntegerValueField(.keyboardEventKeycode)
                if keycode == PointerEventBlocker.escapeKeycode {
                    DispatchQueue.main.async { blocker.onEscape?() }
                    return nil
                }
                if keycode == PointerEventBlocker.returnKeycode {
                    DispatchQueue.main.async { blocker.onReturn?() }
                    return nil
                }
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
        suppressingSwipe = false
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
    }
}
