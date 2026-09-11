import SwiftUI

let appDisplayName = "Live Transcribe"

@main
struct LiveTranscribeApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup(appDisplayName) {
            MainView(model: model)
        }
    }
}
