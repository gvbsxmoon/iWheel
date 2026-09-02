import Foundation
import CoreFoundation
import CMultitouch

/// Streams raw finger positions from the trackpad using the private
/// MultitouchSupport.framework, resolved at runtime via dlopen/dlsym.
final class MultitouchMonitor {
    static let shared = MultitouchMonitor()

    struct TouchPoint {
        let id: Int
        let x: Double   // 0..1, left to right
        let y: Double   // 0..1, bottom to top
        let state: Int  // 4 = touching
    }

    /// Called on the multitouch driver thread for every frame,
    /// including the empty frame when all fingers lift.
    var onFrame: (([TouchPoint]) -> Void)?

    private typealias CreateListFn = @convention(c) () -> Unmanaged<CFMutableArray>?
    private typealias RegisterFn = @convention(c) (UnsafeMutableRawPointer?, MTFrameCallback?) -> Void
    private typealias StartFn = @convention(c) (UnsafeMutableRawPointer?, Int32) -> Void
    private typealias StopFn = @convention(c) (UnsafeMutableRawPointer?) -> Void

    private var devices: [UnsafeMutableRawPointer] = []
    private var stopFn: StopFn?

    func start() throws {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW) else {
            throw WheelError.frameworkUnavailable("MultitouchSupport")
        }
        guard let createSym = dlsym(handle, "MTDeviceCreateList"),
              let registerSym = dlsym(handle, "MTRegisterContactFrameCallback"),
              let startSym = dlsym(handle, "MTDeviceStart") else {
            throw WheelError.symbolMissing("MultitouchSupport")
        }
        if let stopSym = dlsym(handle, "MTDeviceStop") {
            stopFn = unsafeBitCast(stopSym, to: StopFn.self)
        }

        let createList = unsafeBitCast(createSym, to: CreateListFn.self)
        let register = unsafeBitCast(registerSym, to: RegisterFn.self)
        let startDevice = unsafeBitCast(startSym, to: StartFn.self)

        guard let list = createList()?.takeRetainedValue() else {
            throw WheelError.noDevices
        }
        let count = CFArrayGetCount(list)
        guard count > 0 else { throw WheelError.noDevices }

        for i in 0..<count {
            guard let raw = CFArrayGetValueAtIndex(list, i) else { continue }
            let device = UnsafeMutableRawPointer(mutating: raw)
            register(device, iWheelFrameCallback)
            startDevice(device, 0)
            devices.append(device)
        }
    }

    func stop() {
        guard let stopFn else { return }
        for device in devices { stopFn(device) }
        devices.removeAll()
    }

    fileprivate static func dispatch(_ touchesPtr: UnsafeMutablePointer<MTTouch>?, _ count: Int) {
        var points: [TouchPoint] = []
        if let touchesPtr, count > 0 {
            points.reserveCapacity(count)
            for i in 0..<count {
                let t = touchesPtr[i]
                let x = Double(t.normalized.position.x)
                let y = Double(t.normalized.position.y)
                // Out-of-range coordinates mean the private struct layout
                // does not match this machine (untested arch/OS): drop the
                // frame instead of feeding garbage to the gesture engine.
                guard x >= -0.1, x <= 1.1, y >= -0.1, y <= 1.1 else { continue }
                points.append(TouchPoint(
                    id: Int(t.identifier),
                    x: x,
                    y: y,
                    state: Int(t.state)
                ))
            }
        }
        shared.onFrame?(points)
    }
}

// Must be a context-free C function pointer.
private let iWheelFrameCallback: MTFrameCallback = { _, touches, numTouches, _, _ in
    MultitouchMonitor.dispatch(touches, Int(numTouches))
    return 0
}
