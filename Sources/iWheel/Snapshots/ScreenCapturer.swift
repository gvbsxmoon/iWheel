import ScreenCaptureKit

/// The one place that talks to ScreenCaptureKit. Takes a 480px-wide shot
/// of the first display with every window of this app excluded.
@MainActor
final class ScreenCapturer {
    struct Shot {
        let image: CGImage
        /// Whether our app was present in the enumeration and therefore
        /// excluded. When false, a wheel that appeared mid-shot could be
        /// in the frame - the coordinator uses this to validate.
        let ownAppExcluded: Bool
    }

    func capture() async throws -> Shot? {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else { return nil }

        let config = SCStreamConfiguration()
        let targetWidth = 480.0
        let scale = targetWidth / Double(display.width)
        config.width = Int(targetWidth)
        config.height = Int(Double(display.height) * scale)
        config.showsCursor = false

        // Excluding the whole app (not a window list) also covers our
        // windows that appear between content enumeration and the shot.
        let us = content.applications.filter { $0.processID == getpid() }
        let filter = SCContentFilter(display: display, excludingApplications: us, exceptingWindows: [])
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return Shot(image: image, ownAppExcluded: !us.isEmpty)
    }
}
