import AVFoundation
import CoreAudio
import Foundation

enum CaptureState: Equatable {
    case idle
    case running(tapID: AudioObjectID, aggregateID: AudioObjectID)

    mutating func start(tapID: AudioObjectID, aggregateID: AudioObjectID) {
        self = .running(tapID: tapID, aggregateID: aggregateID)
    }

    mutating func stop() { self = .idle }
}

enum SystemAudioCaptureError: LocalizedError {
    case tap(OSStatus)
    case aggregate(OSStatus)
    case format
    case ioProc(OSStatus)
    case start(OSStatus)

    var errorDescription: String? {
        switch self {
        case .tap(let status): "Could not create the system audio tap (\(status))."
        case .aggregate(let status): "Could not create the private audio capture device (\(status))."
        case .format: "Could not read the system audio format."
        case .ioProc(let status): "Could not receive system audio (\(status))."
        case .start(let status): "Could not start system audio capture (\(status))."
        }
    }
}

final class SystemAudioCapture: @unchecked Sendable {
    private let queue = DispatchQueue(label: "LiveTranscribe.SystemAudioCapture")
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private(set) var state: CaptureState = .idle
    private(set) var sourceFormatDescription = ""

    func start(_ onBuffer: @escaping @MainActor (AVAudioPCMBuffer) -> Void) throws {
        stop()

        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        description.isPrivate = true
        description.muteBehavior = .unmuted
        description.name = "live-transcribe-\(UUID().uuidString)"

        var newTapID = AudioObjectID(kAudioObjectUnknown)
        let tapStatus = AudioHardwareCreateProcessTap(description, &newTapID)
        guard tapStatus == noErr else { throw SystemAudioCaptureError.tap(tapStatus) }
        tapID = newTapID

        do {
            let uid = try Self.tapUID(for: tapID)
            let tapFormat = try Self.tapFormat(for: tapID)
            let aggregate = try Self.makeAggregate(tapUID: uid)
            aggregateID = aggregate
            let defaultRate = Self.nominalSampleRate(of: aggregate) ?? tapFormat.mSampleRate
            Self.setNominalSampleRate(of: aggregate, to: max(defaultRate, tapFormat.mSampleRate))
            let actualRate = Self.nominalSampleRate(of: aggregate) ?? tapFormat.mSampleRate
            guard var liveFormat = try Self.inputStreamFormats(of: aggregate).last else {
                throw SystemAudioCaptureError.format
            }
            liveFormat.mSampleRate = actualRate
            sourceFormatDescription = "\(Int(actualRate)) Hz, \(liveFormat.mChannelsPerFrame) channels"
            guard let audioFormat = AVAudioFormat(streamDescription: &liveFormat) else {
                throw SystemAudioCaptureError.format
            }

            let status = AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateID, queue) {
                _, input, _, _, _ in
                guard let copy = Self.copyBuffer(input, format: audioFormat) else { return }
                Task { @MainActor in onBuffer(copy) }
            }
            guard status == noErr, ioProcID != nil else { throw SystemAudioCaptureError.ioProc(status) }

            let startStatus = AudioDeviceStart(aggregateID, ioProcID)
            guard startStatus == noErr else { throw SystemAudioCaptureError.start(startStatus) }
            state.start(tapID: tapID, aggregateID: aggregateID)
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        if let ioProcID, aggregateID != kAudioObjectUnknown {
            AudioDeviceStop(aggregateID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
        }
        ioProcID = nil
        if aggregateID != kAudioObjectUnknown { AudioHardwareDestroyAggregateDevice(aggregateID) }
        aggregateID = AudioObjectID(kAudioObjectUnknown)
        if tapID != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tapID) }
        tapID = AudioObjectID(kAudioObjectUnknown)
        state.stop()
    }

    deinit { stop() }

    private static func tapUID(for tapID: AudioObjectID) throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: CFString?
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, $0)
        }
        guard status == noErr, let value else { throw SystemAudioCaptureError.tap(status) }
        return value as String
    }

    private static func tapFormat(for tapID: AudioObjectID) throws -> AudioStreamBasicDescription {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let status = AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, &format)
        guard status == noErr else { throw SystemAudioCaptureError.tap(status) }
        return format
    }

    private static func makeAggregate(tapUID: String) throws -> AudioObjectID {
        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Live Transcribe Capture",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapUIDKey: tapUID,
                kAudioSubTapDriftCompensationKey: true,
            ]],
        ]
        var aggregateID = AudioObjectID(kAudioObjectUnknown)
        let status = AudioHardwareCreateAggregateDevice(description as CFDictionary, &aggregateID)
        guard status == noErr else { throw SystemAudioCaptureError.aggregate(status) }
        return aggregateID
    }

    private static func nominalSampleRate(of deviceID: AudioObjectID) -> Double? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var rate = 0.0
        var size = UInt32(MemoryLayout<Double>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &rate) == noErr, rate > 0 else {
            return nil
        }
        return rate
    }

    private static func setNominalSampleRate(of deviceID: AudioObjectID, to rate: Double) {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var rate = rate
        _ = AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<Double>.size), &rate)
    }

    private static func inputStreamFormats(of deviceID: AudioObjectID) throws -> [AudioStreamBasicDescription] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr else {
            throw SystemAudioCaptureError.format
        }
        var streams = [AudioStreamID](repeating: 0, count: Int(size) / MemoryLayout<AudioStreamID>.stride)
        guard !streams.isEmpty, streams.withUnsafeMutableBytes({
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, $0.baseAddress!)
        }) == noErr else { throw SystemAudioCaptureError.format }
        return try streams.map { stream in
            var formatAddress = AudioObjectPropertyAddress(
                mSelector: kAudioStreamPropertyVirtualFormat,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var format = AudioStreamBasicDescription()
            var formatSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            guard AudioObjectGetPropertyData(stream, &formatAddress, 0, nil, &formatSize, &format) == noErr else {
                throw SystemAudioCaptureError.format
            }
            return format
        }
    }

    private static func copyBuffer(
        _ input: UnsafePointer<AudioBufferList>, format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let source = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        guard let first = source.first, format.streamDescription.pointee.mBytesPerFrame > 0 else { return nil }
        let frames = AVAudioFrameCount(first.mDataByteSize / format.streamDescription.pointee.mBytesPerFrame)
        guard frames > 0, let copy = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        copy.frameLength = frames
        let destination = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        guard source.count == destination.count else { return nil }
        for index in source.indices {
            guard let sourceData = source[index].mData, let destinationData = destination[index].mData else { return nil }
            memcpy(destinationData, sourceData, Int(source[index].mDataByteSize))
            destination[index].mDataByteSize = source[index].mDataByteSize
        }
        return copy
    }
}
