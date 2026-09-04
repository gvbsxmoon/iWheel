import AppKit
import ScreenCaptureKit

/// Mission Control-style previews: cached snapshots, not live feeds.
/// A frame is captured every time the active space changes (plus a slow
/// periodic refresh), so each space shows how it looked the last time
/// the system displayed it - same perceived behavior as the native thumbnails.
/// Snapshots live in RAM only and are purged on lock and sleep.
@MainActor
final class SnapshotCache: ObservableObject {
    @Published private(set) var images: [UInt64: CGImage] = [:]
    /// Current desktop wallpaper, used as the preview for spaces not yet
    /// visited (instead of a flat placeholder). One wallpaper is assumed
    /// for all spaces - the common case.
    @Published private(set) var wallpaper: CGImage?

    private let spaceManager: SpaceManager
    /// Wired by the controller; captures never run while the wheel is up.
    var overlayIsVisible: () -> Bool = { false }
    private var timer: Timer?
    private var capturing = false
    private var screenIsPrivate = false

    init(spaceManager: SpaceManager) {
        self.spaceManager = spaceManager
    }

    func start() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                await self.waitForSwitchToSettle()
                await self.waitWhileWheelIsOpen()
                await self.captureCurrent()
                self.refreshWallpaper()
            }
        }

        observePrivacyBoundary(DistributedNotificationCenter.default(), "com.apple.screenIsLocked", entering: true)
        observePrivacyBoundary(DistributedNotificationCenter.default(), "com.apple.screenIsUnlocked", entering: false)
        observePrivacyBoundary(NSWorkspace.shared.notificationCenter, NSWorkspace.screensDidSleepNotification.rawValue, entering: true)
        observePrivacyBoundary(NSWorkspace.shared.notificationCenter, NSWorkspace.screensDidWakeNotification.rawValue, entering: false)

        timer = Timer.scheduledTimer(withTimeInterval: 6, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.captureCurrent() }
        }
        Task { await captureCurrent() }
        refreshWallpaper()
    }

    /// Shooting mid-slide stores a frame of two half desktops, so wait for
    /// WindowServer to report the animation over (plus a small settle pad).
    /// Without the private flag, fall back to a delay long enough for the
    /// slowest slide.
    private func waitForSwitchToSettle() async {
        guard spaceManager.canDetectAnimation else {
            try? await Task.sleep(nanoseconds: 700_000_000)
            return
        }
        var waitedMs = 0
        while spaceManager.displayIsAnimating(), waitedMs < 1_500 {
            try? await Task.sleep(nanoseconds: 50_000_000)
            waitedMs += 50
        }
        try? await Task.sleep(nanoseconds: 150_000_000)
    }

    /// Locked or asleep screens must neither keep old snapshots (whatever
    /// was on screen may be sensitive) nor produce new ones (the capture
    /// would show the lock screen).
    private func observePrivacyBoundary(_ center: NotificationCenter, _ name: String, entering: Bool) {
        center.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.screenIsPrivate = entering
                if entering {
                    self.images.removeAll()
                } else {
                    await self.captureCurrent()
                }
            }
        }
    }

    private func refreshWallpaper() {
        guard let screen = NSScreen.main,
              let url = NSWorkspace.shared.desktopImageURL(for: screen),
              let image = NSImage(contentsOf: url) else { return }
        var rect = NSRect(origin: .zero, size: image.size)
        wallpaper = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    /// Reopening the wheel right after landing bars the post-switch shot
    /// (captures never run while it is up), so wait for it to close
    /// instead of dropping the shot - otherwise that space shows no
    /// preview until the periodic refresh. The settle wait runs again
    /// afterwards: closing the wheel usually starts the next switch, and
    /// a landing frame must never come from mid-animation.
    private func waitWhileWheelIsOpen() async {
        while overlayIsVisible() {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        await waitForSwitchToSettle()
    }

    func captureCurrent() async {
        guard !capturing, !screenIsPrivate, !overlayIsVisible(),
              let spaceID = spaceManager.currentSpaceID() else { return }
        capturing = true
        defer { capturing = false }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else { return }

            let config = SCStreamConfiguration()
            let targetWidth = 480.0
            let scale = targetWidth / Double(display.width)
            config.width = Int(targetWidth)
            config.height = Int(Double(display.height) * scale)
            config.showsCursor = false

            // Excluding the whole app (not a window list) also covers our
            // windows that appear between content enumeration and the shot,
            // like the overlay right as the wheel opens.
            let us = content.applications.filter { $0.processID == getpid() }
            let filter = SCContentFilter(display: display, excludingApplications: us, exceptingWindows: [])
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

            // The shot is async: if the space changed mid-capture, storing
            // it under the id read above would caption the wrong space.
            guard spaceManager.currentSpaceID() == spaceID else { return }
            // Exclusion only covers windows that existed at enumeration
            // time: if the wheel opened between enumeration and the shot,
            // it is in the frame with nothing excluding it. Drop that
            // frame; a later capture replaces it.
            guard !(overlayIsVisible() && us.isEmpty) else { return }
            images[spaceID] = image
            prune()
        } catch {
            NSLog("iWheel: snapshot failed: \(String(describing: error))")
        }
    }

    /// Spaces deleted by the user leave orphaned entries behind; drop them
    /// so long-running sessions do not accumulate dead images.
    private func prune() {
        let alive = Set(spaceManager.userSpaces().map(\.id))
        images = images.filter { alive.contains($0.key) }
    }
}
