import XCTest
@testable import LiveTranscribe

final class BacklogTests: XCTestCase {
    func testBacklogBecomesBehindAfterTwoSecondsOfAudio() {
        var backlog = AudioBacklog()
        backlog.enqueue(seconds: 2.1)

        XCTAssertTrue(backlog.isBehind)
    }

    func testSkipToLiveClearsPendingAudioAndMarksGap() {
        var backlog = AudioBacklog()
        backlog.enqueue(seconds: 3)

        XCTAssertEqual(backlog.skipToLiveMarker, "[Skipped 3.0s to return to live]")
        XCTAssertFalse(backlog.isBehind)
    }
}
