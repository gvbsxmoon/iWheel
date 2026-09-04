import Foundation

/// Pure selection math, UI-free so it is unit-testable.
/// Pad coordinates are normalized [0,1]x[0,1], origin bottom-left.
public enum SelectionLogic {
    /// Tab stepping with wrap-around.
    public static func stepped(current: Int, count: Int, backwards: Bool) -> Int {
        guard count > 0 else { return 0 }
        return (current + (backwards ? -1 : 1) + count) % count
    }

    /// Dock selection: rawPosition is a continuous card index (anchor +
    /// horizontal displacement * gain). Hysteresis in card units: a
    /// neighbor steals the highlight only when it is clearly closer than
    /// the current selection. Returns nil to keep it.
    public static func updatedLinearSelection(
        rawPosition: Double,
        current: Int,
        count: Int,
        hysteresis: Double
    ) -> Int? {
        guard count > 0 else { return nil }
        let clamped = min(max(rawPosition, 0), Double(count - 1))
        let candidate = Int(clamped.rounded())
        guard candidate != current, candidate >= 0, candidate < count else { return nil }

        let candidateDistance = abs(clamped - Double(candidate))
        let currentDistance = abs(clamped - Double(current))
        return candidateDistance + hysteresis < currentDistance ? candidate : nil
    }
}
