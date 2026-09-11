import AVFoundation
import FluidAudio
import Foundation

extension AVAudioPCMBuffer: @retroactive @unchecked Sendable {}

struct AudioBacklog: Equatable, Sendable {
    private(set) var seconds = 0.0
    var isBehind: Bool { seconds > 2 }

    mutating func enqueue(seconds: Double) { self.seconds += seconds }
    mutating func dequeue(seconds: Double) { self.seconds = max(0, self.seconds - seconds) }

    var skipToLiveMarker: String {
        mutating get {
            defer { seconds = 0 }
            return String(format: "[Skipped %.1fs to return to live]", seconds)
        }
    }
}

@MainActor
final class StreamingTranscriber {
    typealias Update = @MainActor (_ text: String, _ isFinal: Bool) -> Void

    private var manager: StreamingUnifiedAsrManager?
    private var update: Update?
    private var onBacklogChange: (@MainActor (Bool) -> Void)?
    private var backlog = AudioBacklog()
    private var acceptingUpdates = false

    func prepare(
        onUpdate: @escaping Update,
        onBacklogChange: @escaping @MainActor (Bool) -> Void
    ) async throws {
        let manager = StreamingUnifiedAsrManager(
            config: UnifiedConfig(leftFrames: 70, chunkFrames: 2, rightFrames: 2)
        )
        self.update = onUpdate
        self.onBacklogChange = onBacklogChange
        await manager.setPartialTranscriptCallback { [weak self] text in
            Task { @MainActor in
                guard self?.acceptingUpdates == true else { return }
                self?.update?(text, false)
            }
        }
        try await manager.loadModels()
        self.manager = manager
        acceptingUpdates = true
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        guard let manager, acceptingUpdates else { return }
        let seconds = Double(buffer.frameLength) / buffer.format.sampleRate
        backlog.enqueue(seconds: seconds)
        onBacklogChange?(backlog.isBehind)
        Task {
            defer {
                self.backlog.dequeue(seconds: seconds)
                self.onBacklogChange?(self.backlog.isBehind)
            }
            do {
                try await manager.appendAudio(buffer)
                try await manager.processBufferedAudio()
            } catch {
                self.update?("[Transcription error: \(error.localizedDescription)]", true)
            }
        }
    }

    func finish(onComplete: @escaping @MainActor () -> Void) {
        guard let manager else { return }
        acceptingUpdates = false
        Task {
            defer {
                self.acceptingUpdates = true
                onComplete()
            }
            do {
                let text = try await manager.finish()
                self.update?(text, true)
                try await manager.reset()
            } catch {
                self.update?("[Transcription error: \(error.localizedDescription)]", true)
            }
        }
    }

    func clear() { resetSession() }

    func skipToLive() -> String {
        let marker = backlog.skipToLiveMarker
        resetSession()
        return marker
    }

    private func resetSession() {
        backlog = AudioBacklog()
        onBacklogChange?(false)
        acceptingUpdates = false
        guard let manager else { return }
        Task {
            try? await manager.reset()
            self.acceptingUpdates = true
        }
    }
}
