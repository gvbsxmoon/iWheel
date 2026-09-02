import AppKit
import ScreenCaptureKit

/// Mission Control-style previews: cached snapshots, not live feeds.
/// A frame is captured every time the active space changes (plus a slow
/// periodic refresh), so each desktop shows how it looked the last time
/// the system displayed it - same perceived behavior as the native thumbnails.
@MainActor
final class SnapshotCache: ObservableObject {
    @Published private(set) var images: [UInt64: CGImage] = [:]
    /// Current desktop wallpaper, used as the preview for spaces not yet
    /// visited (instead of a flat placeholder). One wallpaper is assumed
    /// for all spaces - the common case.
    @Published private(set) var wallpaper: CGImage?

    private let spaceManager: SpaceManager
    private var timer: Timer?
    private var capturing = false

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
                // Let the switch animation settle before grabbing the frame.
                try? await Task.sleep(nanoseconds: 400_000_000)
                await self?.captureCurrent()
                self?.refreshWallpaper()
            }
        }
        // Privacy: do not keep desktop snapshots in RAM across a lock or
        // sleep - whatever was on screen may be sensitive.
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.images.removeAll() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.images.removeAll() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 6, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.captureCurrent() }
        }
        Task { await captureCurrent() }
        refreshWallpaper()
    }

    private func refreshWallpaper() {
        guard let screen = NSScreen.main,
              let url = NSWorkspace.shared.desktopImageURL(for: screen),
              let image = NSImage(contentsOf: url) else { return }
        var rect = NSRect(origin: .zero, size: image.size)
        wallpaper = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    func captureCurrent() async {
        guard !capturing, let spaceID = spaceManager.currentSpaceID() else { return }
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

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            images[spaceID] = image
        } catch {
            NSLog("iWheel: snapshot failed: \(String(describing: error))")
        }
    }
}
