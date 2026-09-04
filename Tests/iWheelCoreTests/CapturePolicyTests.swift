import Testing
@testable import iWheelCore

@Suite struct CapturePolicyTests {
    private func policy() -> CapturePolicy {
        CapturePolicy(settleSeconds: 0.85, refreshSeconds: 6)
    }

    @Test func settleWindowOutwaitsTheSlide() {
        var p = policy()
        p.spaceChanged(to: 1, at: 10.0)
        #expect(!p.shouldCapture(at: 10.5))
        #expect(!p.shouldCapture(at: 10.8))
        #expect(p.shouldCapture(at: 10.9))
    }

    @Test func hopChainWaitsForTheLastHop() {
        var p = policy()
        p.spaceChanged(to: 1, at: 10.0)
        p.spaceChanged(to: 2, at: 10.3)
        p.spaceChanged(to: 3, at: 10.6)
        #expect(!p.shouldCapture(at: 11.0))
        #expect(p.shouldCapture(at: 11.5))
        #expect(p.currentSpace == 3)
    }

    @Test func storedCaptureTurnsCleanThenAgesOut() {
        var p = policy()
        p.spaceChanged(to: 1, at: 10.0)
        p.captureStored(id: 1, at: 11.0)
        #expect(!p.shouldCapture(at: 12.0))
        #expect(p.shouldCapture(at: 17.1))
    }

    @Test func discardedShotStaysDirty() {
        var p = policy()
        p.spaceChanged(to: 1, at: 10.0)
        // No captureStored happened: still eligible on the next sample.
        #expect(p.shouldCapture(at: 11.0))
        #expect(p.shouldCapture(at: 11.3))
    }

    @Test func wheelAndPrivacyGateCaptures() {
        var p = policy()
        p.spaceChanged(to: 1, at: 10.0)
        p.wheelChanged(visible: true)
        #expect(!p.shouldCapture(at: 11.0))
        p.wheelChanged(visible: false)
        p.privacyChanged(screenPrivate: true)
        #expect(!p.shouldCapture(at: 11.0))
        p.privacyChanged(screenPrivate: false)
        #expect(p.shouldCapture(at: 11.0))
    }

    @Test func privacyForgetsFreshness() {
        var p = policy()
        p.spaceChanged(to: 1, at: 10.0)
        p.captureStored(id: 1, at: 11.0)
        p.privacyChanged(screenPrivate: true)
        p.privacyChanged(screenPrivate: false)
        // The purge dropped the image; the policy must recapture soon.
        #expect(p.shouldCapture(at: 11.5))
    }

    @Test func interactiveDragGatesCapturesUntilSettledAfterLift() {
        var p = policy()
        p.spaceChanged(to: 1, at: 10.0)
        p.captureStored(id: 1, at: 11.0)
        // Frame ages out while the user starts a slow interactive swipe:
        // the periodic refresh must hold fire for the whole drag.
        p.gestureChanged(active: true, at: 18.0)
        #expect(!p.shouldCapture(at: 19.5))
        p.gestureChanged(active: false, at: 20.0)
        // The lift starts a settle: the release animation is outwaited.
        #expect(!p.shouldCapture(at: 20.5))
        #expect(p.shouldCapture(at: 20.9))
    }

    @Test func staleFrameOfRevisitedSpaceRecaptures() {
        var p = policy()
        p.spaceChanged(to: 1, at: 10.0)
        p.captureStored(id: 1, at: 10.5)
        p.spaceChanged(to: 2, at: 20.0)
        p.captureStored(id: 2, at: 20.6)
        p.spaceChanged(to: 1, at: 30.0)
        // Space 1's frame is 20s old: dirty again on arrival.
        #expect(p.shouldCapture(at: 30.9))
    }
}
