import AppKit
import SwiftUI

enum AppStatus: Equatable {
    case preparing
    case finishing
    case ready
    case recording
    case failed(String)

    var label: String {
        switch self {
        case .preparing: "Preparing model…"
        case .finishing: "Finishing…"
        case .ready: "Ready"
        case .recording: "Recording"
        case .failed(let message): message
        }
    }

    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var transcript: Transcript
    @Published private(set) var status: AppStatus
    @Published var followLive = true
    @Published var isBehind = false
    @Published var alwaysOnTop: Bool {
        didSet { UserDefaults.standard.set(alwaysOnTop, forKey: Self.alwaysOnTopKey) }
    }

    private static let alwaysOnTopKey = "alwaysOnTop"
    private let transcriber = StreamingTranscriber()
    private let capture = SystemAudioCapture()
    private var preserveVisibleTextOnStop = false

    init(prepare: Bool = true, transcript: Transcript = Transcript()) {
        self.transcript = transcript
        self.status = prepare ? .preparing : .ready
        self.alwaysOnTop = UserDefaults.standard.bool(forKey: Self.alwaysOnTopKey)
        if prepare { self.prepare() }
    }

    static func forTesting(transcript: Transcript) -> AppModel {
        AppModel(prepare: false, transcript: transcript)
    }

    var isRecording: Bool {
        if case .recording = status { return true }
        return false
    }

    func prepare() {
        status = .preparing
        Task {
            do {
                try await transcriber.prepare(
                    onUpdate: { [weak self] text, isFinal in
                        guard let self, !text.isEmpty else { return }
                        if isFinal {
                            if !self.preserveVisibleTextOnStop {
                                self.transcript.commitSession(text)
                            }
                            self.preserveVisibleTextOnStop = false
                        } else {
                            self.transcript.showPartialTranscript(text)
                        }
                    },
                    onBacklogChange: { [weak self] isBehind in self?.isBehind = isBehind }
                )
                status = .ready
            } catch {
                status = .failed("Model preparation failed: \(error.localizedDescription)")
            }
        }
    }

    func toggleCapture() {
        if isRecording {
            capture.stop()
            preserveVisibleTextOnStop = transcript.commitPartial()
            status = .finishing
            transcriber.finish { [weak self] in self?.status = .ready }
            return
        }
        guard case .ready = status else { return }
        do {
            preserveVisibleTextOnStop = false
            try capture.start { [weak self] buffer in self?.transcriber.append(buffer) }
            status = .recording
        } catch {
            status = .failed("System audio capture failed: \(error.localizedDescription)")
        }
    }

    func clear() {
        transcript.clear()
        if isRecording { transcriber.clear() }
    }

    func skipToLive() {
        transcript.commit(transcript.displayText + "\n" + transcriber.skipToLive())
        isBehind = false
    }
}
