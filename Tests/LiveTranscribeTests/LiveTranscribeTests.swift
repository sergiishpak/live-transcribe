import XCTest
@testable import LiveTranscribe

final class LiveTranscribeTests: XCTestCase {
    func testPackageExposesAppName() {
        XCTAssertEqual(appDisplayName, "Live Transcribe")
    }
}
