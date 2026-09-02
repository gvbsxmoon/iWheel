import Foundation

/// Pure wheel-selection math, UI-free so it is unit-testable.
/// Pad coordinates are normalized [0,1]x[0,1], origin bottom-left.
/// Bearings are degrees: 0 at 12 o'clock, growing clockwise - the same
/// layout the wheel uses (desktop 1 on top, clockwise).
public enum SelectionLogic {
    /// nil at the exact center, where a bearing is undefined.
    public static func bearing(x: Double, y: Double) -> Double? {
        let dx = x - 0.5
        let dy = y - 0.5
        guard dx != 0 || dy != 0 else { return nil }
        var b = atan2(dx, dy) * 180 / .pi
        if b < 0 { b += 360 }
        return b
    }

    public static func angularDistance(_ a: Double, _ b: Double) -> Double {
        let d = abs(a - b).truncatingRemainder(dividingBy: 360)
        return d > 180 ? 360 - d : d
    }

    public static func nearestSector(bearing: Double, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let sector = 360.0 / Double(count)
        return Int((bearing / sector).rounded()) % count
    }

    /// Hysteresis rule: a neighbor steals the highlight only when it is
    /// clearly closer than the current selection. Returns nil to keep it.
    public static func updatedSelection(
        bearing: Double,
        current: Int,
        count: Int,
        hysteresisDegrees: Double
    ) -> Int? {
        guard count > 0 else { return nil }
        let sector = 360.0 / Double(count)
        let candidate = nearestSector(bearing: bearing, count: count)
        guard candidate != current else { return nil }

        let candidateDistance = angularDistance(bearing, Double(candidate) * sector)
        let currentDistance = angularDistance(bearing, Double(current) * sector)
        return candidateDistance + hysteresisDegrees < currentDistance ? candidate : nil
    }

    /// Tab stepping with wrap-around.
    public static func stepped(current: Int, count: Int, backwards: Bool) -> Int {
        guard count > 0 else { return 0 }
        return (current + (backwards ? -1 : 1) + count) % count
    }
}
