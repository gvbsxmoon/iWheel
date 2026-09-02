import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Form {
            Section("General") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(isOn: $settings.launchAtLogin) {
                        Text("Open at login")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text("Starts iWheel automatically when you log in. Requires running the iWheel.app bundle, not the bare binary.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 2)
            }
            Section("Gestures") {
                setting("Activation hold",
                        caption: "How long to keep 3 fingers still before the wheel appears. Longer means fewer accidental openings.",
                        value: $settings.holdSeconds, in: 0.15...0.6, format: "%.2fs")
            }
            Section("Navigation") {
                setting("Movement threshold",
                        caption: "How decisively you must point at a nearby desktop before the highlight jumps to it. Higher is steadier, lower is snappier.",
                        value: $settings.hysteresisDegrees, in: 0...15, format: "%.0f deg")
                setting("Center dead zone",
                        caption: "A small area around where your fingers start, ignored while pointing. Higher means you move further before the highlight reacts.",
                        value: $settings.deadZone, in: 0.03...0.20, format: "%.2f")
                VStack(alignment: .leading, spacing: 4) {
                    Picker(selection: $settings.hapticStyle) {
                        ForEach(SettingsStore.HapticStyle.allCases) { style in
                            Text(style.rawValue.capitalized).tag(style)
                        }
                    } label: {
                        Text("Haptic feedback")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text("The little trackpad click you feel every time the highlight moves to another desktop.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 2)
            }
            Section("Appearance") {
                setting("Ring size",
                        caption: "How wide the circle of desktops is on screen.",
                        value: $settings.ringRadius, in: 80...240, format: "%.0f pt")
                setting("Highlight zoom",
                        caption: "How much the highlighted desktop grows compared to the others.",
                        value: $settings.zoomScale, in: 1.1...2.5, format: "%.2fx")
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 620)
    }

    /// Inline row (label - slider - value) with a small caption below.
    private func setting(_ title: String, caption: String, value: Binding<Double>, in range: ClosedRange<Double>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Slider(value: value, in: range)
                Text(String(format: format, value.wrappedValue))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .trailing)
            }
            Text(caption)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }
}

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(settings: settings))
            let w = NSWindow(contentViewController: hosting)
            w.title = "iWheel Settings"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            window = w
        }
        if let window, let screen = NSScreen.main {
            // Opens on the left side of the desktop, vertically centered.
            let frame = window.frame
            let origin = NSPoint(
                x: screen.visibleFrame.minX + 24,
                y: screen.visibleFrame.midY - frame.height / 2
            )
            window.setFrameOrigin(origin)
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
