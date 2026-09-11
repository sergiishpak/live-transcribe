import SwiftUI

let appDisplayName = "Live Transcribe"

@main
struct LiveTranscribeApp: App {
    var body: some Scene {
        WindowGroup(appDisplayName) {
            Text("Preparing…")
                .frame(minWidth: 420, minHeight: 240)
        }
    }
}
