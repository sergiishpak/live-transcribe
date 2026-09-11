import XCTest
@testable import LiveTranscribe

final class TranscriptTests: XCTestCase {
    func testCommittedWordsStayWhenPartialTextChanges() {
        var transcript = Transcript()
        transcript.showPartial("hello wor")
        transcript.commit("hello world")
        transcript.showPartial("how are")

        XCTAssertEqual(transcript.displayText, "hello world how are")
    }

    func testClearRemovesCommittedAndPartialText() {
        var transcript = Transcript(committed: "keep", partial: " this")
        transcript.clear()

        XCTAssertEqual(transcript.displayText, "")
    }

    func testStoppingLaterSessionAppendsToExistingTranscript() {
        var transcript = Transcript(committed: "first call")
        transcript.commitSession("second call")

        XCTAssertEqual(transcript.displayText, "first call second call")
    }

    func testCommitPartialPreservesVisibleLiveText() {
        var transcript = Transcript(committed: "first call", partial: " second call")

        XCTAssertTrue(transcript.commitPartial())
        XCTAssertEqual(transcript.displayText, "first call second call")
    }
}
