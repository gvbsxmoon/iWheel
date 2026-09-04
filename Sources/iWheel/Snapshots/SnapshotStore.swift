import AppKit

/// The snapshot system's published state: previews by space id plus the
/// wallpaper fallback for spaces never visited. RAM only, by design.
@MainActor
final class SnapshotStore: ObservableObject {
    @Published private(set) var images: [UInt64: CGImage] = [:]
    /// One wallpaper is assumed for all spaces - the common case.
    @Published private(set) var wallpaper: CGImage?

    func store(_ image: CGImage, for id: UInt64) {
        images[id] = image
    }

    /// Spaces deleted by the user leave orphaned entries behind; drop
    /// them so long-running sessions do not accumulate dead images.
    func prune(keeping alive: Set<UInt64>) {
        images = images.filter { alive.contains($0.key) }
    }

    /// Lock and sleep: whatever was on screen may be sensitive.
    func purgeAll() {
        images.removeAll()
    }

    func refreshWallpaper() {
        guard let screen = NSScreen.main,
              let url = NSWorkspace.shared.desktopImageURL(for: screen),
              let image = NSImage(contentsOf: url) else { return }
        var rect = NSRect(origin: .zero, size: image.size)
        wallpaper = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}
