import Testing
@testable import LiveTranscribe

struct TranscriptTests {
    @Test func testCommittedWordsStayWhenPartialTextChanges() {
        var transcript = Transcript()
        transcript.showPartial("hello wor")
        transcript.commit("hello world")
        transcript.showPartial("how are")

        #expect(transcript.displayText == "hello world how are")
    }

    @Test func testClearRemovesCommittedAndPartialText() {
        var transcript = Transcript(committed: "keep", partial: " this")
        transcript.clear()

        #expect(transcript.displayText == "")
    }

    @Test func testStoppingLaterSessionAppendsToExistingTranscript() {
        var transcript = Transcript(committed: "first call")
        transcript.commitSession("second call")

        #expect(transcript.displayText == "first call second call")
    }

    @Test func testCommitPartialPreservesVisibleLiveText() {
        var transcript = Transcript(committed: "first call", partial: " second call")

        let didCommit = transcript.commitPartial()
        #expect(didCommit)
        #expect(transcript.displayText == "first call second call")
    }

    @Test func testSentencesSeparateFinishedAndLiveText() {
        let transcript = Transcript(committed: "First sentence. Second sentence!", partial: " Still speaking")

        #expect(transcript.sentences == ["First sentence.", "Second sentence!", "Still speaking"])
    }
}
