import AppKit
import Foundation

struct SpaceInfo: Identifiable, Equatable {
    let id: UInt64
    /// 1-based number among numbered desktops, in Mission Control order.
    /// nil for fullscreen-app spaces, which macOS does not number.
    let desktopNumber: Int?
    /// Localized app name for fullscreen-app spaces, nil for desktops.
    let appName: String?
    let isCurrent: Bool

    var isFullscreen: Bool { desktopNumber == nil }
    /// What the user calls this space: "3" or the app's name.
    var label: String { appName ?? desktopNumber.map(String.init) ?? "?" }
}

/// Reads the Spaces topology from the private SkyLight framework.
/// Read-only usage: the actual switching goes through synthetic
/// Mission Control shortcuts (see SpaceSwitcher).
final class SpaceManager {
    private typealias MainConnectionFn = @convention(c) () -> Int32
    private typealias CopySpacesFn = @convention(c) (Int32) -> Unmanaged<CFArray>?

    private let connection: Int32
    private let copySpaces: CopySpacesFn

    init() throws {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW) else {
            throw WheelError.frameworkUnavailable("SkyLight")
        }
        // SLS names are current; CGS names survive as aliases on older builds.
        guard let mainSym = dlsym(handle, "SLSMainConnectionID") ?? dlsym(handle, "CGSMainConnectionID"),
              let copySym = dlsym(handle, "SLSCopyManagedDisplaySpaces") ?? dlsym(handle, "CGSCopyManagedDisplaySpaces") else {
            throw WheelError.symbolMissing("SkyLight")
        }
        connection = unsafeBitCast(mainSym, to: MainConnectionFn.self)()
        copySpaces = unsafeBitCast(copySym, to: CopySpacesFn.self)
    }

    /// All switchable spaces on the first display, in Mission Control
    /// order: numbered desktops (type 0) and fullscreen apps (type 4,
    /// named after their owning process).
    func allSpaces() -> [SpaceInfo] {
        guard let display = displays().first else { return [] }
        let currentID = ((display["Current Space"] as? [String: Any])?["id64"] as? NSNumber)?.uint64Value
        let raw = display["Spaces"] as? [[String: Any]] ?? []

        var result: [SpaceInfo] = []
        var desktopNumber = 0
        for dict in raw {
            guard let id = (dict["id64"] as? NSNumber)?.uint64Value else { continue }
            switch (dict["type"] as? NSNumber)?.intValue ?? 0 {
            case 0:
                desktopNumber += 1
                result.append(SpaceInfo(id: id, desktopNumber: desktopNumber, appName: nil, isCurrent: id == currentID))
            case 4:
                let pid = (dict["pid"] as? NSNumber)?.int32Value
                let name = pid.flatMap { NSRunningApplication(processIdentifier: $0)?.localizedName }
                result.append(SpaceInfo(id: id, desktopNumber: nil, appName: name ?? "App", isCurrent: id == currentID))
            default:
                continue
            }
        }
        return result
    }

    func currentSpaceID() -> UInt64? {
        guard let display = displays().first else { return nil }
        return ((display["Current Space"] as? [String: Any])?["id64"] as? NSNumber)?.uint64Value
    }

    private func displays() -> [[String: Any]] {
        guard let cf = copySpaces(connection)?.takeRetainedValue() else { return [] }
        return (cf as NSArray) as? [[String: Any]] ?? []
    }
}
