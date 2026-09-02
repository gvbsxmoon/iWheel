import CoreGraphics
import Foundation

/// Hides the cursor while the wheel is open. A background app normally may
/// not hide the cursor; the private SetsCursorInBackground connection
/// property (the same trick Karabiner-Elements uses) lifts the restriction.
final class CursorHider {
    private var hidden = false

    init() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW),
              let mainSym = dlsym(handle, "SLSMainConnectionID") ?? dlsym(handle, "CGSMainConnectionID"),
              let setSym = dlsym(handle, "SLSSetConnectionProperty") ?? dlsym(handle, "CGSSetConnectionProperty")
        else { return }
        typealias MainFn = @convention(c) () -> Int32
        typealias SetFn = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32
        let cid = unsafeBitCast(mainSym, to: MainFn.self)()
        _ = unsafeBitCast(setSym, to: SetFn.self)(cid, cid, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
    }

    func hide() {
        guard !hidden else { return }
        CGDisplayHideCursor(CGMainDisplayID())
        hidden = true
    }

    func show() {
        guard hidden else { return }
        CGDisplayShowCursor(CGMainDisplayID())
        hidden = false
    }
}
