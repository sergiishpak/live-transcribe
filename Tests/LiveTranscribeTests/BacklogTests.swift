import Testing
@testable import LiveTranscribe

struct BacklogTests {
    @Test func testBacklogBecomesBehindAfterTwoSecondsOfAudio() {
        var backlog = AudioBacklog()
        backlog.enqueue(seconds: 2.1)

        #expect(backlog.isBehind)
    }

    @Test func testSkipToLiveClearsPendingAudioAndMarksGap() {
        var backlog = AudioBacklog()
        backlog.enqueue(seconds: 3)

        #expect(backlog.skipToLiveMarker == "[Skipped 3.0s to return to live]")
        #expect(!backlog.isBehind)
    }
}
