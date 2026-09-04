import AppKit
import QuartzCore
import iWheelCore

/// Wires the snapshot system together: SpaceObserver feeds events into
/// the pure CapturePolicy, a lightweight sampler asks the policy when a
/// quiet moment arrives, ScreenCapturer takes the shot, and the frame
/// reaches the SnapshotStore only after validation.
///
/// A frame is stored only when the space id is the same before and after
/// the shot, no slide animation is running afterwards, and the shot could
/// not contain our own wheel. Anything else is discarded; the policy
/// stays dirty and the next sample retries. No timeout ever forces an
/// early shot - that timeout was how previews ended up showing the wrong
/// space.
@MainActor
final class SnapshotCoordinator {
    let store = SnapshotStore()

    private var policy = CapturePolicy()
    private let observer = SpaceObserver()
    private let capturer = ScreenCapturer()
    private let spaceManager: SpaceManager
    private var sampler: Timer?
    private var capturing = false
    private var wheelVisible = false

    init(spaceManager: SpaceManager) {
        self.spaceManager = spaceManager
    }

    func start() {
        observer.onSpaceChanged = { [weak self] in
            guard let self else { return }
            self.policy.spaceChanged(to: self.spaceManager.currentSpaceID(), at: CACurrentMediaTime())
            self.store.refreshWallpaper()
        }
        observer.onPrivacyBoundary = { [weak self] entering in
            guard let self else { return }
            self.policy.privacyChanged(screenPrivate: entering)
            if entering { self.store.purgeAll() }
        }
        observer.start()

        // Seed past the settle window so the launch capture is immediate.
        policy.spaceChanged(to: spaceManager.currentSpaceID(), at: CACurrentMediaTime() - policy.settleSeconds)
        store.refreshWallpaper()

        // The sampler is a handful of comparisons per tick; the animation
        // flag is only consulted once every other gate has passed.
        sampler = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        sample()
    }

    /// Wheel lifecycle, reported by the controller. Closing samples right
    /// away so a capture deferred by the open wheel lands immediately.
    func wheelDidOpen() {
        wheelVisible = true
        policy.wheelChanged(visible: true)
    }

    func wheelDidClose() {
        wheelVisible = false
        policy.wheelChanged(visible: false)
        sample()
    }

    /// Reported by the controller from the raw touch stream: 3+ fingers
    /// can drive an interactive space drag, which must never be shot.
    func gestureChanged(active: Bool) {
        policy.gestureChanged(active: active, at: CACurrentMediaTime())
    }

    private func sample() {
        guard !capturing, policy.shouldCapture(at: CACurrentMediaTime()),
              !MissionControl.isActive else { return }
        Task { await captureNow() }
    }

    private func captureNow() async {
        guard !capturing else { return }
        capturing = true
        defer { capturing = false }

        guard let spaceID = spaceManager.currentSpaceID() else { return }
        do {
            guard let shot = try await capturer.capture() else { return }
            // Validation: discarding beats storing a lie. The policy was
            // not told, so it retries at the next quiet sample.
            guard spaceManager.currentSpaceID() == spaceID,
                  !MissionControl.isActive,
                  !(wheelVisible && !shot.ownAppExcluded) else { return }

            store.store(shot.image, for: spaceID)
            store.prune(keeping: Set(spaceManager.allSpaces().map(\.id)))
            policy.captureStored(id: spaceID, at: CACurrentMediaTime())
        } catch {
            NSLog("iWheel: snapshot failed: \(String(describing: error))")
        }
    }
}
