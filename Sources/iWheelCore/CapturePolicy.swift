import Foundation

/// Decides when a space-preview capture may fire. Pure state machine:
/// callers feed events with timestamps and sample `shouldCapture`; no
/// clocks, timers or system calls live in here, so event timelines are
/// unit-testable.
///
/// The invariant that kills wrong-space previews: a capture fires only
/// when the last space change is at least `settleSeconds` old. The value
/// is conservative because it is the ONLY defense against shooting the
/// slide animation: macOS stopped reporting space-animation state to
/// third parties (SLSManagedDisplayIsAnimating returns garbage on modern
/// releases - verified empirically, and yabai's source says the same),
/// so the slide plus its spring tail must simply be outwaited. There is
/// no timeout that forces an early shot; a moment that never turns quiet
/// keeps the capture pending, and a discarded shot retries on the next
/// sample.
public struct CapturePolicy {
    private(set) public var currentSpace: UInt64?
    private var currentIsDirty = false
    private var lastSwitchAt: TimeInterval = -.greatestFiniteMagnitude
    private var lastGestureEndAt: TimeInterval = -.greatestFiniteMagnitude
    private var gestureActive = false
    private var lastCaptureAt: [UInt64: TimeInterval] = [:]
    private var wheelVisible = false
    private var screenPrivate = false

    /// Minimum age of the last space change before a shot may fire.
    /// Covers the slide animation and its spring tail with margin.
    public let settleSeconds: TimeInterval
    /// A clean frame older than this is recaptured on the next sample.
    public let refreshSeconds: TimeInterval

    public init(settleSeconds: TimeInterval = 0.85, refreshSeconds: TimeInterval = 6) {
        self.settleSeconds = settleSeconds
        self.refreshSeconds = refreshSeconds
    }

    // MARK: - Events

    public mutating func spaceChanged(to id: UInt64?, at t: TimeInterval) {
        currentSpace = id
        currentIsDirty = true
        lastSwitchAt = t
    }

    public mutating func wheelChanged(visible: Bool) {
        wheelVisible = visible
    }

    /// A multi-finger contact that can drive an interactive space drag.
    /// While fingers are down the screen can show two half spaces for
    /// SECONDS with no notification in sight - the one state no
    /// notification-based settle can cover, and where the periodic
    /// refresh used to shoot its slivers. The lift starts a settle so the
    /// release animation is outwaited too.
    public mutating func gestureChanged(active: Bool, at t: TimeInterval) {
        if gestureActive && !active {
            lastGestureEndAt = t
        }
        gestureActive = active
    }

    /// Lock or display sleep. The store purges its images alongside this;
    /// forgetting freshness here makes everything recapture after unlock.
    public mutating func privacyChanged(screenPrivate: Bool) {
        self.screenPrivate = screenPrivate
        if screenPrivate {
            lastCaptureAt = [:]
            currentIsDirty = true
        }
    }

    /// A validated frame reached the store. Discarded or failed shots
    /// call nothing: the space stays dirty and the next sample retries.
    public mutating func captureStored(id: UInt64, at t: TimeInterval) {
        lastCaptureAt[id] = t
        if id == currentSpace {
            currentIsDirty = false
        }
    }

    // MARK: - The gate

    public func shouldCapture(at t: TimeInterval) -> Bool {
        guard !screenPrivate, !wheelVisible, !gestureActive, let current = currentSpace else { return false }
        guard t - lastSwitchAt >= settleSeconds else { return false }
        guard t - lastGestureEndAt >= settleSeconds else { return false }
        let fresh = lastCaptureAt[current].map { t - $0 < refreshSeconds } ?? false
        return currentIsDirty || !fresh
    }
}
