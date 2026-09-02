import Foundation

struct SpaceInfo: Identifiable, Equatable {
    let id: UInt64
    let index: Int      // 1-based position among user spaces on the main display
    let isCurrent: Bool
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

    /// User spaces (type 0) on the first display, in Mission Control order.
    /// Fullscreen-app spaces are skipped: they have no ctrl+N shortcut.
    func userSpaces() -> [SpaceInfo] {
        guard let display = displays().first else { return [] }
        let currentID = ((display["Current Space"] as? [String: Any])?["id64"] as? NSNumber)?.uint64Value
        let raw = display["Spaces"] as? [[String: Any]] ?? []

        var result: [SpaceInfo] = []
        var userIndex = 0
        for dict in raw {
            let type = (dict["type"] as? NSNumber)?.intValue ?? 0
            guard type == 0 else { continue }
            guard let id = (dict["id64"] as? NSNumber)?.uint64Value else { continue }
            userIndex += 1
            result.append(SpaceInfo(
                id: id,
                index: userIndex,
                isCurrent: id == currentID
            ))
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
