import XCTest
@testable import LiveTranscribe

final class LiveTranscribeTests: XCTestCase {
    func testPackageExposesAppName() {
        XCTAssertEqual(appDisplayName, "Live Transcribe")
    }

    @MainActor
    func testClearRemovesTextWithoutChangingReadyState() {
        let model = AppModel.forTesting(transcript: Transcript(committed: "hello"))
        model.clear()

        XCTAssertEqual(model.transcript.displayText, "")
        XCTAssertEqual(model.status, .ready)
    }
}
