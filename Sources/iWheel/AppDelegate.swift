import AppKit
import ApplicationServices
import IOKit.hid

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var wheel: WheelController?
    private var snapshots: SnapshotCoordinator?
    private let settings = SettingsStore()
    private lazy var settingsWindow = SettingsWindowController(settings: settings)
    private lazy var helpWindow = HelpWindowController(settings: settings)
    private let hotkey = GlobalHotkey()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        requestPermissions()

        do {
            let spaceManager = try SpaceManager()
            let snapshots = SnapshotCoordinator(spaceManager: spaceManager)
            let wheel = WheelController(spaceManager: spaceManager, snapshots: snapshots, settings: settings)
            self.snapshots = snapshots
            self.wheel = wheel

            snapshots.start()
            MultitouchMonitor.shared.onFrame = { touches in
                wheel.handleFrame(touches)
            }
            try MultitouchMonitor.shared.start()

            hotkey.onPressed = { [weak wheel] in wheel?.toggleLatched() }
            hotkey.apply(keyCode: settings.hotkeyKeyCode, modifiers: settings.hotkeyModifiers)
            settings.hotkeyChanged = { [weak self] in
                guard let self else { return }
                self.hotkey.apply(keyCode: self.settings.hotkeyKeyCode, modifiers: self.settings.hotkeyModifiers)
            }
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
        let hint = NSMenuItem(title: "iWheel - rest 3 fingers, slide, release to go", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        let helpItem = NSMenuItem(title: "Help", action: #selector(openHelp), keyEquivalent: "")
        helpItem.target = self
        helpItem.image = NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: "Help")
        menu.addItem(helpItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    /// Mirrors the app icon: three space cards in a diagonal cascade.
    /// Template image - the depth is carried by alpha, and each card is
    /// painted with .copy so it punches out the one behind it (translucent
    /// over opaque would otherwise stay opaque and kill the tones).
    private static func makeStatusIcon() -> NSImage {
        let side: CGFloat = 18
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            func card(x: CGFloat, y: CGFloat, alpha: CGFloat) {
                let frame = NSRect(x: x, y: y, width: 11.5, height: 8.5)
                // Hairline of transparency around the card, so the stack
                // reads as separate cards instead of one blob.
                NSGraphicsContext.current?.compositingOperation = .copy
                NSColor.black.withAlphaComponent(0).setFill()
                NSBezierPath(roundedRect: frame.insetBy(dx: -0.8, dy: -0.8), xRadius: 3.2, yRadius: 3.2).fill()
                NSColor.black.withAlphaComponent(alpha).setFill()
                NSBezierPath(roundedRect: frame, xRadius: 2.6, yRadius: 2.6).fill()
            }

            // Back to front, bottom-right ending on top like the app icon.
            card(x: 0.2, y: 8.8, alpha: 0.4)
            card(x: 3.2, y: 4.9, alpha: 0.65)
            card(x: 6.2, y: 1.0, alpha: 1.0)
            return true
        }
        image.isTemplate = true
        return image
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }

    @objc private func openHelp() {
        helpWindow.show()
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
