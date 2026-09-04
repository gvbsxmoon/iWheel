import AppKit
import SwiftUI

@MainActor
final class OverlayWindowController {
    private var panel: NSPanel?

    func show(controller: WheelController, snapshots: SnapshotCache, settings: SettingsStore) {
        if panel == nil {
            let p = NSPanel(
                contentRect: .zero,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false
            p.level = .screenSaver
            p.ignoresMouseEvents = true
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
            p.contentView = NSHostingView(rootView: WheelView(controller: controller, snapshots: snapshots, settings: settings))
            panel = p
        }
        guard let panel, let screen = NSScreen.main else { return }
        let dock = WheelView.dockPanelSize(
            spacing: settings.dockSpacing,
            count: controller.spaces.count,
            cardWidth: settings.cardWidth,
            zoom: settings.zoomScale
        )
        let size = NSSize(width: dock.width, height: dock.height)
        let origin = NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.midY - size.height / 2
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func hide() {
        panel?.orderOut(nil)
    }
}
