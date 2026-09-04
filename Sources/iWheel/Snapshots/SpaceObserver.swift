import AppKit

/// The snapshot system's only ear on the OS: space changes and privacy
/// boundaries (lock, display sleep) become plain callbacks.
@MainActor
final class SpaceObserver {
    var onSpaceChanged: (() -> Void)?
    /// true = entering a private state (locked / asleep), false = leaving it.
    var onPrivacyBoundary: ((Bool) -> Void)?

    func start() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.onSpaceChanged?() }
        }

        observe(DistributedNotificationCenter.default(), "com.apple.screenIsLocked", entering: true)
        observe(DistributedNotificationCenter.default(), "com.apple.screenIsUnlocked", entering: false)
        observe(NSWorkspace.shared.notificationCenter, NSWorkspace.screensDidSleepNotification.rawValue, entering: true)
        observe(NSWorkspace.shared.notificationCenter, NSWorkspace.screensDidWakeNotification.rawValue, entering: false)
    }

    private func observe(_ center: NotificationCenter, _ name: String, entering: Bool) {
        center.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.onPrivacyBoundary?(entering) }
        }
    }
}
