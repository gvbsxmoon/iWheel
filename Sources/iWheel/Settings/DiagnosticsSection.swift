import IOKit.hid
import ScreenCaptureKit
import SwiftUI

struct PermissionStatus: Identifiable {
    let id: String
    let name: String
    let purpose: String
    let granted: Bool
    let pane: SettingsPane

    static func checkAll() -> [PermissionStatus] {
        [
            PermissionStatus(
                id: "input",
                name: "Input Monitoring",
                purpose: "Reads finger positions on the trackpad.",
                granted: IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted,
                pane: .inputMonitoring
            ),
            PermissionStatus(
                id: "ax",
                name: "Accessibility",
                purpose: "Performs the actual space switch.",
                granted: AXIsProcessTrusted(),
                pane: .accessibility
            ),
            PermissionStatus(
                id: "screen",
                name: "Screen Recording",
                purpose: "Takes the space previews.",
                granted: CGPreflightScreenCaptureAccess(),
                pane: .screenRecording
            ),
        ]
    }
}

/// Settings section: the three permissions at a glance, with a direct
/// route to the exact System Settings pane when one is missing.
struct DiagnosticsSection: View {
    @State private var permissions = PermissionStatus.checkAll()

    var body: some View {
        Section("Diagnostics") {
            ForEach(permissions) { permission in
                HStack(spacing: 10) {
                    Circle()
                        .fill(permission.granted ? .green : .red)
                        .frame(width: 9, height: 9)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(permission.name)
                            .font(.system(size: 14, weight: .semibold))
                        Text(permission.purpose)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !permission.granted {
                        Button("Open Settings") { permission.pane.open() }
                            .font(.system(size: 12))
                    }
                }
                .padding(.vertical, 2)
            }
            Button("Recheck") { permissions = PermissionStatus.checkAll() }
                .font(.system(size: 12))
        }
        .onAppear { permissions = PermissionStatus.checkAll() }
    }
}
