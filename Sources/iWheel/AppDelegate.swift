import AppKit
import ApplicationServices
import IOKit.hid

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var wheel: WheelController?
    private var snapshots: SnapshotCache?
    private let settings = SettingsStore()
    private lazy var settingsWindow = SettingsWindowController(settings: settings)

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        requestPermissions()

        do {
            let spaceManager = try SpaceManager()
            let snapshots = SnapshotCache(spaceManager: spaceManager)
            let wheel = WheelController(spaceManager: spaceManager, snapshots: snapshots, settings: settings)
            self.snapshots = snapshots
            self.wheel = wheel

            snapshots.start()
            MultitouchMonitor.shared.onFrame = { touches in
                wheel.handleFrame(touches)
            }
            try MultitouchMonitor.shared.start()
        } catch {
            showFatal(error)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        MultitouchMonitor.shared.stop()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = Self.makeStatusIcon()
        statusItem.button?.setAccessibilityLabel("iWheel")
        let menu = NSMenu()
        let hint = NSMenuItem(title: "iWheel - rest 3 fingers, point with 2, release to go", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    /// Mirrors the app icon: a solid disc with a softer inner disc.
    /// Template image - the two tones are carried by alpha so the menu bar
    /// tints it correctly in light and dark appearance.
    private static func makeStatusIcon() -> NSImage {
        let side: CGFloat = 18
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let center = CGPoint(x: rect.midX, y: rect.midY)

            func disc(diameter: CGFloat, alpha: CGFloat, operation: NSCompositingOperation = .sourceOver) {
                NSGraphicsContext.current?.compositingOperation = operation
                NSColor.black.withAlphaComponent(alpha).setFill()
                NSBezierPath(ovalIn: NSRect(
                    x: center.x - diameter / 2, y: center.y - diameter / 2,
                    width: diameter, height: diameter
                )).fill()
            }

            disc(diameter: 15, alpha: 1.0)
            // .copy REPLACES the pixels: painting translucent black over
            // opaque black would otherwise stay opaque and kill the two-tone.
            disc(diameter: 6, alpha: 0.5, operation: .copy)
            return true
        }
        image.isTemplate = true
        return image
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }

    private func requestPermissions() {
        // Accessibility: needed to post the synthetic ctrl+N key events.
        let axOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(axOptions)
        // Screen Recording: needed by ScreenCaptureKit for the previews.
        _ = CGRequestScreenCaptureAccess()
        // Input Monitoring: raw multitouch stream.
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    private func showFatal(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "iWheel cannot start"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .critical
        alert.runModal()
        NSApp.terminate(nil)
    }
}
