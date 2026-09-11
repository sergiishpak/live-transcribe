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

    private var manager: StreamingEouAsrManager?
    private var update: Update?

    func prepare(onUpdate: @escaping Update) async throws {
        let manager = StreamingEouAsrManager(chunkSize: .ms160)
        self.update = onUpdate
        await manager.setPartialCallback { [weak self] text in
            Task { @MainActor in self?.update?(text, false) }
        }
        await manager.setEouCallback { [weak self] text in
            Task { @MainActor in self?.update?(text, true) }
        }
        try await manager.loadModels()
        self.manager = manager
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        guard let manager else { return }
        Task {
            do {
                try await manager.appendAudio(buffer)
                try await manager.processBufferedAudio()
            } catch {
                self.update?("[Transcription error: \(error.localizedDescription)]", true)
            }
        }
    }

    func finish() {
        guard let manager else { return }
        Task {
            do {
                let text = try await manager.finish()
                self.update?(text, true)
                await manager.reset()
            } catch {
                self.update?("[Transcription error: \(error.localizedDescription)]", true)
            }
        }
    }
}
