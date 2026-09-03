import AppKit
import ApplicationServices
import QuartzCore
import iWheelCore

/// The gesture engine.
/// - Rest THREE fingers still on the pad for the configured hold: the wheel
///   opens. A moving 3-finger contact is left to macOS, so quick system
///   swipes keep switching desktop natively.
/// - Point with TWO fingers: the bearing relative to where the wheel was
///   opened highlights that desktop, with smoothing and angular hysteresis.
///   3+ fingers never navigate: any drift closes the wheel in favor of the
///   system gesture, which cannot be blocked app-side.
/// - Tab / shift+Tab: step the highlight.
/// - RELEASE: switch to the highlighted desktop. Releasing on the current
///   desktop does nothing, which doubles as cancel.
@MainActor
final class WheelController: ObservableObject {
    @Published private(set) var spaces: [SpaceInfo] = []
    @Published private(set) var selectedIndex: Int = 0

    private enum State { case idle, wheel }
    private var state: State = .idle

    private var holdStart: CFTimeInterval = 0
    private var holdCancelled = false
    private var idleStartPositions: [Int: (x: Double, y: Double)] = [:]
    private var lastTouchTime: CFTimeInterval = 0
    private var waitingForClear = false
    private var watchdog: Timer?
    private var smoothed: (x: Double, y: Double)?

    private let releaseCommitSeconds = 0.15
    private let smoothingFactor = 0.30
    /// A finger travelling further than this while 3+ are down is a system
    /// swipe: pre-activation the wheel stays closed, post-activation it
    /// closes and lets the native gesture win.
    private let swipeCancelDistance = 0.05
    /// The compass center: where the 3 fingers were held at activation,
    /// so pointing is relative to the hand, not to the pad center.
    private var wheelCenter: (x: Double, y: Double) = (0.5, 0.5)
    /// After a Tab press, positional selection stays locked until the
    /// fingers really move - the micro-shift of pressing a key must not
    /// steal the focus Tab just set.
    private var tabLockArm = false
    private var tabLockPoint: (x: Double, y: Double)?
    private let tabUnlockDistance = 0.08
    /// Dock layout: the card index anchored to the activation point.
    private var dockAnchorIndex = 0
    /// Keyboard-opened (latched) mode: the wheel stays open with no fingers.
    /// The pointing center is set by the first touch, and release-commit
    /// only arms once navigation has actually happened.
    private var latched = false
    private var latchedAwaitingCenter = false
    private var hasNavigated = false

    let settings: SettingsStore
    private let spaceManager: SpaceManager
    private let switcher = SpaceSwitcher()
    private let overlay = OverlayWindowController()
    private let blocker = PointerEventBlocker()
    private let cursor = CursorHider()
    private let hud = HUDController()
    let snapshots: SnapshotCache

    init(spaceManager: SpaceManager, snapshots: SnapshotCache, settings: SettingsStore) {
        self.spaceManager = spaceManager
        self.snapshots = snapshots
        self.settings = settings
        blocker.onSwallowedClick = { [weak self] in
            guard let self, self.state == .wheel else { return }
            self.commit()
        }
        blocker.onEscape = { [weak self] in
            guard let self, self.state == .wheel else { return }
            self.close()
        }
        blocker.onReturn = { [weak self] in
            guard let self, self.state == .wheel else { return }
            self.commit()
        }
        blocker.onTab = { [weak self] backwards in
            guard let self, self.state == .wheel else { return }
            self.lastTouchTime = CACurrentMediaTime()
            self.selectedIndex = SelectionLogic.stepped(current: self.selectedIndex, count: self.spaces.count, backwards: backwards)
            self.smoothed = nil
            self.tabLockArm = true
            self.tabLockPoint = nil
            self.settings.performHaptic()
        }
    }

    nonisolated func handleFrame(_ touches: [MultitouchMonitor.TouchPoint]) {
        DispatchQueue.main.async {
            MainActor.assumeIsolated { self.process(touches) }
        }
    }

    private func process(_ all: [MultitouchMonitor.TouchPoint]) {
        let touching = all.filter { $0.state >= 3 && $0.state <= 5 }

        switch state {
        case .idle:
            processIdle(touching)
        case .wheel:
            guard !touching.isEmpty else { return } // release handled by watchdog
            lastTouchTime = CACurrentMediaTime()
            hasNavigated = true
            let c = centroid(of: touching)

            // Latched (keyboard) open: no fingers were down at activation,
            // so the pointing center is wherever the first touch lands.
            if latchedAwaitingCenter {
                wheelCenter = c
                dockAnchorIndex = selectedIndex
                latchedAwaitingCenter = false
            }

            // While the wheel is open the event tap suppresses the system's
            // own swipe gestures (Spaces, Mission Control), so 3+ fingers
            // are simply ignored here: they may rest on the pad (as right
            // after activation) without navigating or closing anything.
            // Navigation is 2 fingers only: no system gesture exists there
            // (the cursor is hidden and scrolls are swallowed while open),
            // and 1 finger is reserved so an accidental brush does not move
            // the focus.
            if touching.count >= 3 {
                smoothed = nil
                return
            }
            guard touching.count == 2 else {
                smoothed = nil
                return
            }
            select(at: c)
        }
    }

    private func processIdle(_ touching: [MultitouchMonitor.TouchPoint]) {
        if waitingForClear || holdCancelled {
            if touching.isEmpty {
                waitingForClear = false
                holdCancelled = false
                resetHold()
            }
            return
        }
        guard touching.count >= 3 else {
            resetHold()
            return
        }

        if holdStart == 0 {
            holdStart = CACurrentMediaTime()
            idleStartPositions = [:]
        }
        // Stationarity check: a swipe must stay with macOS.
        for t in touching {
            if let start = idleStartPositions[t.id] {
                if hypot(t.x - start.x, t.y - start.y) > swipeCancelDistance {
                    holdCancelled = true
                    resetHold()
                    return
                }
            } else {
                idleStartPositions[t.id] = (t.x, t.y)
            }
        }
        if CACurrentMediaTime() - holdStart >= settings.holdSeconds {
            openWheel(at: centroid(of: touching))
        }
    }

    private func resetHold() {
        holdStart = 0
        idleStartPositions = [:]
    }

    // MARK: - Wheel lifecycle

    /// Keyboard shortcut entry point: toggles the wheel in latched mode.
    func toggleLatched() {
        if state == .wheel {
            close()
        } else if state == .idle {
            latched = true
            latchedAwaitingCenter = true
            openWheel(at: (0.5, 0.5))
        }
    }

    private func openWheel(at activationCenter: (x: Double, y: Double)) {
        resetHold()
        spaces = spaceManager.userSpaces()
        guard !spaces.isEmpty else { return }

        selectedIndex = spaces.firstIndex(where: { $0.isCurrent }) ?? 0
        dockAnchorIndex = selectedIndex
        lastTouchTime = CACurrentMediaTime()
        smoothed = nil
        wheelCenter = activationCenter
        tabLockArm = false
        tabLockPoint = nil
        state = .wheel
        switcher.prepare(desktopCount: spaces.count)

        overlay.show(controller: self, snapshots: snapshots, settings: settings)
        blocker.enable()
        cursor.hide()
        settings.performHaptic()
        // Refresh the current desktop's preview right away: our windows are
        // excluded from the capture, so the wheel itself is not in the shot.
        Task { await snapshots.captureCurrent() }

        watchdog = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.state == .wheel else { return }
                // Latched mode stays open with no fingers until the user
                // navigates (then release commits) or presses Esc/Return.
                if self.latched && !self.hasNavigated { return }
                if CACurrentMediaTime() - self.lastTouchTime > self.releaseCommitSeconds {
                    self.commit()
                }
            }
        }
    }

    private func select(at raw: (x: Double, y: Double)) {
        // Post-Tab lock: ignore position until the fingers really move,
        // so pressing the key does not undo the Tab step.
        if tabLockArm {
            if let lock = tabLockPoint {
                guard hypot(raw.x - lock.x, raw.y - lock.y) > tabUnlockDistance else { return }
                tabLockArm = false
                tabLockPoint = nil
            } else {
                tabLockPoint = raw
                return
            }
        }

        let s: (x: Double, y: Double)
        if let previous = smoothed {
            s = (previous.x + (raw.x - previous.x) * smoothingFactor,
                 previous.y + (raw.y - previous.y) * smoothingFactor)
        } else {
            s = raw
        }
        smoothed = s

        if settings.layout == .dock {
            // Horizontal mapping: 70% of the pad width sweeps all cards,
            // anchored at the activation point on the current desktop.
            // Elasticity: dockSpan% of the trackpad slides through all
            // spaces. Lower span = snappier.
            let gain = Double(spaces.count) / (settings.dockSpan / 100.0)
            let raw = Double(dockAnchorIndex) + (s.x - wheelCenter.x) * gain
            guard let updated = SelectionLogic.updatedLinearSelection(
                rawPosition: raw,
                current: selectedIndex,
                count: spaces.count,
                hysteresis: 0.15
            ) else { return }
            selectedIndex = updated
            settings.performHaptic()
            return
        }

        // Hand-relative compass: translate so the activation point becomes
        // the center SelectionLogic expects at (0.5, 0.5).
        let rx = s.x - wheelCenter.x + 0.5
        let ry = s.y - wheelCenter.y + 0.5

        guard hypot(rx - 0.5, ry - 0.5) > settings.deadZone,
              let bearing = SelectionLogic.bearing(x: rx, y: ry),
              let updated = SelectionLogic.updatedSelection(
                  bearing: bearing,
                  current: selectedIndex,
                  count: spaces.count,
                  hysteresisDegrees: settings.hysteresisDegrees
              ) else { return }

        selectedIndex = updated
        settings.performHaptic()
    }

    private func commit() {
        guard spaces.indices.contains(selectedIndex) else { close(); return }
        let target = spaces[selectedIndex]
        close()

        guard !target.isCurrent else { return }

        guard AXIsProcessTrusted() else {
            // Fires the native permission modal that deep-links into System Settings.
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            hud.show("Accessibility permission needed: grant it in the window that just opened, then try again")
            return
        }
        if target.index > switcher.maxReachableIndex {
            hud.show("Space \(target.index) is beyond \(switcher.maxReachableIndex): not reachable via ctrl+N shortcuts")
            return
        }
        switcher.switchTo(index: target.index)
        verifySwitch(to: target)
    }

    private func close() {
        state = .idle
        waitingForClear = true
        resetHold()
        smoothed = nil
        latched = false
        latchedAwaitingCenter = false
        hasNavigated = false
        watchdog?.invalidate()
        watchdog = nil
        blocker.disable()
        cursor.show()
        overlay.hide()
    }

    private func verifySwitch(to target: SpaceInfo) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard let self else { return }
            if self.spaceManager.currentSpaceID() != target.id {
                self.hud.show("Switch did not happen. Enable \"Switch to Desktop \(target.index)\" in System Settings > Keyboard > Shortcuts > Mission Control")
            }
        }
    }

    private func centroid(of touches: [MultitouchMonitor.TouchPoint]) -> (x: Double, y: Double) {
        let n = Double(touches.count)
        let sx = touches.reduce(0.0) { $0 + $1.x }
        let sy = touches.reduce(0.0) { $0 + $1.y }
        return (sx / n, sy / n)
    }
}
