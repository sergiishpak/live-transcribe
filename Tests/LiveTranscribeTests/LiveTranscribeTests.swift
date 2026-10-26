import Testing
@testable import LiveTranscribe

struct LiveTranscribeTests {
    @Test func testPackageExposesAppName() {
        #expect(appDisplayName == "Live Transcribe")
    }

    @MainActor
    @Test func testClearRemovesTextWithoutChangingReadyState() {
        let model = AppModel.forTesting(transcript: Transcript(committed: "hello"))
        model.clear()

        #expect(model.transcript.displayText == "")
        #expect(model.status == .ready)
    }
}
