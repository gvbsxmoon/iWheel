import AppKit
import ApplicationServices
import QuartzCore
import iWheelCore

/// The gesture engine.
/// - Rest THREE fingers still on the pad for the configured hold: the
///   switcher opens. A moving 3-finger contact is left to macOS, so quick
///   system swipes keep switching desktop natively.
/// - Slide horizontally (3 fingers by default, 2 via Settings) to move the
///   highlight along the dock, anchored where the fingers were held.
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
    private var reportedGestureActive = false

    let settings: SettingsStore
    private let spaceManager: SpaceManager
    private let switcher = SpaceSwitcher()
    private let overlay = OverlayWindowController()
    private let blocker = PointerEventBlocker()
    private let cursor = CursorHider()
    private let hud = HUDController()
    let snapshots: SnapshotCoordinator

    init(spaceManager: SpaceManager, snapshots: SnapshotCoordinator, settings: SettingsStore) {
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

        // 3+ fingers can drive an interactive space drag: the capture
        // system must hold fire from first contact until settle after lift.
        let gestureActive = touching.count >= 3
        if gestureActive != reportedGestureActive {
            reportedGestureActive = gestureActive
            snapshots.gestureChanged(active: gestureActive)
        }

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
            // own swipe gestures, so 3 fingers are free to navigate: the
            // default flow is hold 3 to open and keep sliding with the same
            // 3 fingers. A Settings picker switches navigation to 2 fingers
            // for people who prefer the lift-one style. Any other count
            // rests without navigating.
            guard touching.count == settings.navFingers else {
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
        spaces = spaceManager.allSpaces()
        // Mission Control owns the screen and our panel would open unseen
        // behind it; refuse and clear any latch the hotkey path just set.
        guard !spaces.isEmpty, !MissionControl.isActive else {
            latched = false
            latchedAwaitingCenter = false
            return
        }

        selectedIndex = spaces.firstIndex(where: { $0.isCurrent }) ?? 0
        dockAnchorIndex = selectedIndex
        lastTouchTime = CACurrentMediaTime()
        smoothed = nil
        wheelCenter = activationCenter
        tabLockArm = false
        tabLockPoint = nil
        state = .wheel
        switcher.prepare(desktopCount: spaces.compactMap(\.desktopNumber).count)

        overlay.show(controller: self, snapshots: snapshots.store, settings: settings)
        blocker.enable()
        cursor.hide()
        settings.performHaptic()
        snapshots.wheelDidOpen()

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

        // Horizontal mapping anchored at the activation point: elasticity
        // (dockSpan) is the percent of the pad width that sweeps through
        // all spaces. Lower span = snappier. Natural drags the row like
        // the system gesture (fingers left reach the space on the right);
        // inverted moves the highlight with the fingers.
        let gain = Double(spaces.count) / (settings.dockSpan / 100.0)
        let direction: Double = settings.scrollDirection == .natural ? -1 : 1
        let position = Double(dockAnchorIndex) + (s.x - wheelCenter.x) * gain * direction
        guard let updated = SelectionLogic.updatedLinearSelection(
            rawPosition: position,
            current: selectedIndex,
            count: spaces.count,
            hysteresis: 0.15
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
            hud.show(SwitchFailure.accessibilityMissing.message)
            return
        }
        performSwitch(to: target, isRetry: false)
    }

    /// Numbered desktops within ctrl+N reach jump directly; fullscreen
    /// apps and desktops past 10 hop there with the move-a-space shortcut,
    /// which macOS chains into one continuous slide.
    private func performSwitch(to target: SpaceInfo, isRetry: Bool) {
        var hops = 0
        if let n = target.desktopNumber, n <= switcher.maxDirectIndex {
            switcher.switchTo(index: n)
        } else {
            let current = spaceManager.allSpaces()
            guard let from = current.firstIndex(where: { $0.isCurrent }),
                  let to = current.firstIndex(where: { $0.id == target.id }),
                  from != to else { return }
            hops = to - from
            let steps = hops
            Task { await switcher.move(steps: steps) }
        }
        verifySwitch(to: target, hops: abs(hops), isRetry: isRetry)
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
        snapshots.wheelDidClose()
    }

    private func verifySwitch(to target: SpaceInfo, hops: Int, isRetry: Bool) {
        Task { @MainActor [weak self] in
            // Hops chain their slide animations, so the deadline grows
            // with the distance travelled.
            try? await Task.sleep(nanoseconds: 800_000_000 + UInt64(hops) * 150_000_000)
            guard let self, self.spaceManager.currentSpaceID() != target.id else { return }
            let direct = (target.desktopNumber ?? Int.max) <= self.switcher.maxDirectIndex
            if isRetry {
                self.hud.show(SwitchFailure.switchDidNotHappen(target: target, viaDirectJump: direct).message)
                return
            }
            // The usual cause is a disabled Mission Control shortcut;
            // repair and retry once silently before bothering the user.
            // The retry re-plans from the space we actually ended up on.
            self.switcher.prepare(desktopCount: self.spaces.compactMap(\.desktopNumber).count)
            self.performSwitch(to: target, isRetry: true)
        }
    }

    private func centroid(of touches: [MultitouchMonitor.TouchPoint]) -> (x: Double, y: Double) {
        let n = Double(touches.count)
        let sx = touches.reduce(0.0) { $0 + $1.x }
        let sy = touches.reduce(0.0) { $0 + $1.y }
        return (sx / n, sy / n)
    }
}
