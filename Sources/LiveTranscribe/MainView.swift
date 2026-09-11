import AppKit
import SwiftUI

struct MainView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(model.isRecording ? "Stop" : "Start") { model.toggleCapture() }
                    .keyboardShortcut(.return, modifiers: [])
                    .disabled(model.status == .preparing || model.status == .finishing)
                Button("Clear") { model.clear() }
                Spacer()
                Toggle("Always on Top", isOn: $model.alwaysOnTop)
                    .toggleStyle(.checkbox)
            }
            .padding(12)

            TranscriptTextView(text: model.transcript.displayText, followLive: $model.followLive)
                .frame(minWidth: 460, minHeight: 280)

            HStack {
                Text(model.isBehind ? "Catching up" : model.status.label)
                    .foregroundStyle(model.status.isFailure ? .red : .secondary)
                Spacer()
                if model.isBehind {
                    Button("Skip to Live") { model.skipToLive() }
                }
                if !model.followLive {
                    Button("Jump to Live") { model.followLive = true }
                }
                if case .failed = model.status {
                    Button("Retry") { model.prepare() }
                }
            }
            .font(.footnote)
            .padding(12)
        }
        .background(WindowOptions(alwaysOnTop: model.alwaysOnTop))
    }
}

private struct WindowOptions: NSViewRepresentable {
    let alwaysOnTop: Bool

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.setFrameAutosaveName("LiveTranscribeMainWindow")
            window.level = alwaysOnTop ? .floating : .normal
        }
    }
}
