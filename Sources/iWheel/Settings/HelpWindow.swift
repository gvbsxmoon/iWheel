import AppKit
import SwiftUI

struct HelpView: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("How to use iWheel")
                    .font(.system(size: 20, weight: .bold, design: .rounded))

                step("1. Open it",
                     "Rest 3 fingers STILL on the trackpad for a moment. Or press \(settings.hotkeyDisplay) to open it from the keyboard - that way it stays open until you act.")
                step("2. Pick a space",
                     "Keep sliding with \(settings.navFingers) fingers: as they travel, the highlight moves through your spaces, with a little haptic click on each one. Prefer the keyboard? Tab steps to the next space.")
                step("3. Switch",
                     "Lift your fingers and you are there. If you were using Tab, press Return to confirm instead. Landing on the space you started from does nothing.")
                step("4. Changed your mind?",
                     "Press Esc, or just release without moving. While the switcher is open it owns the trackpad: system swipes wait their turn and are back the instant it closes.")

                Divider()

                step("Good to know",
                     "Space previews are snapshots taken as you visit them; spaces you have not visited yet show your wallpaper. Layout, sizes, haptics and the shortcut are all in Settings. iWheel never changes your Mac's gestures.")
            }
            .padding(24)
        }
        .frame(width: 460, height: 480)
    }

    private func step(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
            Text(body)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

@MainActor
final class HelpWindowController {
    private var window: NSWindow?
    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: HelpView(settings: settings))
            let w = NSWindow(contentViewController: hosting)
            w.title = "iWheel Help"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            window = w
        }
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
