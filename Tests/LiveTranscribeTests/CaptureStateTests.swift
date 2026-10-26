import Testing
@testable import LiveTranscribe

struct CaptureStateTests {
    @Test func testStartThenStopReturnsToIdle() {
        var state = CaptureState.idle
        state.start(tapID: 41, aggregateID: 42)
        state.stop()

        #expect(state == .idle)
    }
}
