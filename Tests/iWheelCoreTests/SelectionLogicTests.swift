import Testing
@testable import iWheelCore

@Suite struct SelectionLogicTests {
    private func near(_ a: Double?, _ b: Double, tolerance: Double = 0.001) -> Bool {
        guard let a else { return false }
        return abs(a - b) < tolerance
    }

    @Test func bearingCardinalDirections() {
        #expect(near(SelectionLogic.bearing(x: 0.5, y: 1.0), 0))   // top
        #expect(near(SelectionLogic.bearing(x: 1.0, y: 0.5), 90))  // right
        #expect(near(SelectionLogic.bearing(x: 0.5, y: 0.0), 180)) // bottom
        #expect(near(SelectionLogic.bearing(x: 0.0, y: 0.5), 270)) // left
    }

    @Test func bearingUndefinedAtCenter() {
        #expect(SelectionLogic.bearing(x: 0.5, y: 0.5) == nil)
    }

    @Test func nearestSectorMapping() {
        #expect(SelectionLogic.nearestSector(bearing: 0, count: 12) == 0)
        #expect(SelectionLogic.nearestSector(bearing: 29, count: 12) == 1)
        #expect(SelectionLogic.nearestSector(bearing: 14, count: 12) == 0)
        #expect(SelectionLogic.nearestSector(bearing: 359, count: 12) == 0) // wraps to top
        #expect(SelectionLogic.nearestSector(bearing: 90, count: 4) == 1)
    }

    @Test func angularDistanceWrapsAround() {
        #expect(near(SelectionLogic.angularDistance(350, 10), 20))
        #expect(near(SelectionLogic.angularDistance(0, 180), 180))
        #expect(near(SelectionLogic.angularDistance(90, 90), 0))
    }

    @Test func hysteresisKeepsSelectionNearBoundary() {
        // 12 desktops -> 30 degree sectors. Boundary between 0 and 1 is at 15.
        // At 16 degrees the candidate (1) is closer, but not by the margin.
        #expect(SelectionLogic.updatedSelection(bearing: 16, current: 0, count: 12, hysteresisDegrees: 5) == nil)
        // Well inside sector 1 the switch happens.
        #expect(SelectionLogic.updatedSelection(bearing: 25, current: 0, count: 12, hysteresisDegrees: 5) == 1)
    }

    @Test func hysteresisWrapsAcrossTop() {
        // Bearing 340 with 12 desktops: nearest is sector 11 (center 330).
        #expect(SelectionLogic.updatedSelection(bearing: 340, current: 0, count: 12, hysteresisDegrees: 5) == 11)
    }

    @Test func sameSectorReturnsNil() {
        #expect(SelectionLogic.updatedSelection(bearing: 2, current: 0, count: 12, hysteresisDegrees: 5) == nil)
    }

    @Test func steppedWrapsBothWays() {
        #expect(SelectionLogic.stepped(current: 11, count: 12, backwards: false) == 0)
        #expect(SelectionLogic.stepped(current: 0, count: 12, backwards: true) == 11)
        #expect(SelectionLogic.stepped(current: 5, count: 12, backwards: false) == 6)
    }
}
