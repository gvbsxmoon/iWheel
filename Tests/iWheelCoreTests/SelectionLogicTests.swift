import Testing
@testable import iWheelCore

@Suite struct SelectionLogicTests {
    @Test func steppedWrapsBothWays() {
        #expect(SelectionLogic.stepped(current: 11, count: 12, backwards: false) == 0)
        #expect(SelectionLogic.stepped(current: 0, count: 12, backwards: true) == 11)
        #expect(SelectionLogic.stepped(current: 5, count: 12, backwards: false) == 6)
    }

    @Test func linearSelectionMovesWhenClearlyCloser() {
        #expect(SelectionLogic.updatedLinearSelection(rawPosition: 2.0, current: 0, count: 5, hysteresis: 0.15) == 2)
        #expect(SelectionLogic.updatedLinearSelection(rawPosition: 0.9, current: 0, count: 5, hysteresis: 0.15) == 1)
    }

    @Test func linearHysteresisHoldsNearBoundary() {
        // At 0.55 the candidate (1) is nearer, but not by the 0.15 margin.
        #expect(SelectionLogic.updatedLinearSelection(rawPosition: 0.55, current: 0, count: 5, hysteresis: 0.15) == nil)
    }

    @Test func linearSelectionClampsToEnds() {
        #expect(SelectionLogic.updatedLinearSelection(rawPosition: -3.0, current: 2, count: 5, hysteresis: 0.15) == 0)
        #expect(SelectionLogic.updatedLinearSelection(rawPosition: 99, current: 2, count: 5, hysteresis: 0.15) == 4)
    }

    @Test func linearSameCardReturnsNil() {
        #expect(SelectionLogic.updatedLinearSelection(rawPosition: 0.1, current: 0, count: 5, hysteresis: 0.15) == nil)
        #expect(SelectionLogic.updatedLinearSelection(rawPosition: 0.5, current: 0, count: 1, hysteresis: 0.15) == nil)
    }
}
