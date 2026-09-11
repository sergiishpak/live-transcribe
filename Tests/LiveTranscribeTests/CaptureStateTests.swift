import XCTest
@testable import LiveTranscribe

final class CaptureStateTests: XCTestCase {
    func testStartThenStopReturnsToIdle() {
        var state = CaptureState.idle
        state.start(tapID: 41, aggregateID: 42)
        state.stop()

        XCTAssertEqual(state, .idle)
    }
}
