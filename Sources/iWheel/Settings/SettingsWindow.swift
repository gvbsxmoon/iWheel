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
                VStack(alignment: .leading, spacing: 4) {
                    Picker(selection: $settings.navFingers) {
                        Text("3 fingers").tag(3)
                        Text("2 fingers").tag(2)
                    } label: {
                        Text("Navigate with")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .pickerStyle(.segmented)
                    Text("With 3, you open and keep sliding with the same fingers. With 2, lift one finger after opening to navigate.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 2)
                ShortcutRecorderRow(settings: settings)
            }
            Section("Appearance") {
                VStack(alignment: .leading, spacing: 4) {
                    Picker(selection: $settings.layout) {
                        Text("Wheel").tag(SettingsStore.Layout.wheel)
                        Text("Dock").tag(SettingsStore.Layout.dock)
                    } label: {
                        Text("Layout")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .pickerStyle(.segmented)
                    Text("Wheel arranges your spaces in a circle around your fingers. Dock lays them in a horizontal row that magnifies the highlighted one.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 2)
                if settings.layout == .wheel {
                    setting("Ring size",
                            caption: "How wide the circle of spaces is on screen.",
                            value: $settings.ringRadius, in: 80...240, format: "%.0f pt", step: 10)
                } else {
                    setting("Card spacing",
                            caption: "The distance between space cards in the dock row.",
                            value: $settings.dockSpacing, in: 100...220, format: "%.0f pt", step: 10)
                }
                setting("Card size",
                        caption: "The base size of each space card before any zoom.",
                        value: $settings.cardWidth, in: 60...140, format: "%.0f pt", step: 10)
                setting("Highlight zoom",
                        caption: "How much the highlighted space grows compared to the others.",
                        value: $settings.zoomScale, in: 1.1...2.5, format: "%.2fx", step: 0.1)
            }
            Section("Navigation") {
                if settings.layout == .wheel {
                    setting("Movement threshold",
                            caption: "How much finger travel it takes before the highlight jumps to a nearby space. Higher is steadier, lower is snappier.",
                            value: $settings.hysteresisDegrees, in: 0...15, format: "%.0f deg")
                    setting("Center dead zone",
                            caption: "A small area around where your fingers start, ignored while sliding.",
                            value: $settings.deadZone, in: 0.03...0.20, format: "%.2f")
                } else {
                    setting("Elasticity",
                            caption: "How much of the trackpad you sweep to slide through all your spaces. Lower is snappier, higher gives finer control.",
                            value: $settings.dockSpan, in: 15...70, format: "%.0f%%", step: 5)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Picker(selection: $settings.hapticStyle) {
                        ForEach(SettingsStore.HapticStyle.allCases) { style in
                            Text(style.rawValue.capitalized).tag(style)
                        }
                    } label: {
                        Text("Haptic feedback")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text("The little trackpad click you feel every time the highlight moves to another space.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 2)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 660)
    }

    /// Inline row (label - slider - value) with a small caption below.
    private func setting(_ title: String, caption: String, value: Binding<Double>, in range: ClosedRange<Double>, format: String, step: Double? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                if let step {
                    Slider(value: value, in: range, step: step)
                } else {
                    Slider(value: value, in: range)
                }
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

/// Click, press the new combination, done. Esc cancels the recording.
private struct ShortcutRecorderRow: View {
    @ObservedObject var settings: SettingsStore
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Open shortcut")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(recording ? "Press keys..." : settings.hotkeyDisplay) {
                    recording ? stopRecording() : startRecording()
                }
            }
            Text("Opens the switcher from the keyboard and keeps it open: slide on the trackpad or press Tab to highlight a space, Return confirms, Esc closes. Click and press a new combination including cmd, option or control.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }

    private func startRecording() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            defer { stopRecording() }
            guard event.keyCode != 53 else { return nil } // Esc cancels

            var carbon = 0
            var symbols = ""
            if event.modifierFlags.contains(.control) { carbon |= 4096; symbols += "⌃" }
            if event.modifierFlags.contains(.option) { carbon |= 2048; symbols += "⌥" }
            if event.modifierFlags.contains(.shift) { carbon |= 512; symbols += "⇧" }
            if event.modifierFlags.contains(.command) { carbon |= 256; symbols += "⌘" }
            // Require a real chord, or every plain keystroke would open it.
            guard carbon & (4096 | 2048 | 256) != 0 else {
                NSSound.beep()
                return nil
            }
            settings.hotkeyKeyCode = Int(event.keyCode)
            settings.hotkeyModifiers = carbon
            settings.hotkeyDisplay = symbols + (event.charactersIgnoringModifiers?.uppercased() ?? "?")
            return nil
        }
    }

    private func stopRecording() {
        recording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
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
