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
}
