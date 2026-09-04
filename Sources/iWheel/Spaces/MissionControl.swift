import AppKit
import CoreGraphics

/// Mission Control has no public "is it open" API. While it is up, the
/// Dock puts extra full-screen overlay windows on screen (measured: one
/// per display at layer 20 normally, three at layers 18-20 during
/// Mission Control), so more overlays than displays means it is showing.
enum MissionControl {
    static var isActive: Bool {
        guard let list = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        let overlays = list.filter {
            ($0[kCGWindowOwnerName as String] as? String) == "Dock"
                && ($0[kCGWindowLayer as String] as? Int ?? 0) >= 18
        }
        return overlays.count > NSScreen.screens.count
    }
}
