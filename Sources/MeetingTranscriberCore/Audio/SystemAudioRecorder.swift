@preconcurrency import AVFoundation
import CoreAudio
import Foundation

public final class SystemAudioRecorder: @unchecked Sendable {
    public enum RecorderError: Error, CustomStringConvertible {
        case tapCreationFailed(OSStatus)
        case tapFormatUnreadable(OSStatus)
        case aggregateCreationFailed(OSStatus)
        case ioProcCreationFailed(OSStatus)
        case deviceStartFailed(OSStatus)
        case fileCreationFailed(Error)

        public var description: String {
            switch self {
            case .tapCreationFailed(let s):
                return "process tap creation failed (OSStatus \(s)) — check System Settings → Privacy & Security → Screen & System Audio Recording"
            case .tapFormatUnreadable(let s): return "couldn't read tap stream format (OSStatus \(s))"
            case .aggregateCreationFailed(let s): return "aggregate device creation failed (OSStatus \(s))"
            case .ioProcCreationFailed(let s): return "IO proc creation failed (OSStatus \(s))"
            case .deviceStartFailed(let s): return "device start failed (OSStatus \(s))"
            case .fileCreationFailed(let e): return "output file creation failed: \(e)"
            }
        }
    }

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private var file: AVAudioFile?
    private let queue = DispatchQueue(label: "com.meetingtranscriber.system-tap")
    public private(set) var isRecording = false
    public private(set) var firstBufferAt: Date?

    public init() {}

    public func start(writingTo url: URL) throws {
        guard !isRecording else { return }

        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        description.name = "MeetingTranscriber system tap"
        description.isPrivate = true
        description.muteBehavior = .unmuted

        var newTapID = AudioObjectID(kAudioObjectUnknown)
        let status = AudioHardwareCreateProcessTap(description, &newTapID)
        guard status == noErr else { throw RecorderError.tapCreationFailed(status) }
        tapID = newTapID

        do {
            let format = try tapStreamFormat()
            try createAggregateDevice(tapUUID: description.uuid)
            file = try makeFile(url: url, format: format)
            try installIOProc(format: format)
        } catch {
            cleanup()
            throw error
        }

        isRecording = true
    }

    public func stop() {
        guard isRecording else { return }
        isRecording = false
        if let procID, aggregateID != kAudioObjectUnknown {
            AudioDeviceStop(aggregateID, procID)
        }
        cleanup()
    }

    private func tapStreamFormat() throws -> AVAudioFormat {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var asbd = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let status = AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, &asbd)
        guard status == noErr, let format = AVAudioFormat(streamDescription: &asbd) else {
            throw RecorderError.tapFormatUnreadable(status)
        }
        return format
    }

    private func createAggregateDevice(tapUUID: UUID) throws {
        let desc: [String: Any] = [
            kAudioAggregateDeviceNameKey: "MeetingTranscriber-Tap",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceTapListKey: [
                [kAudioSubTapDriftCompensationKey: true, kAudioSubTapUIDKey: tapUUID.uuidString]
            ],
        ]

        var newDeviceID = AudioObjectID(kAudioObjectUnknown)
        let status = AudioHardwareCreateAggregateDevice(desc as CFDictionary, &newDeviceID)
        guard status == noErr else { throw RecorderError.aggregateCreationFailed(status) }
        aggregateID = newDeviceID
    }

    private func makeFile(url: URL, format: AVAudioFormat) throws -> AVAudioFile {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64000
        ]
        do {
            return try AVAudioFile(
                forWriting: url,
                settings: settings,
                commonFormat: format.commonFormat,
                interleaved: format.isInterleaved
            )
        } catch {
            throw RecorderError.fileCreationFailed(error)
        }
    }

    private func installIOProc(format: AVAudioFormat) throws {
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let status = AudioDeviceCreateIOProcID(
            aggregateID,
            { (_, now, inInputData, _, _, _, clientData) -> OSStatus in
                guard let clientData else { return noErr }
                let recorder = Unmanaged<SystemAudioRecorder>.fromOpaque(clientData).takeUnretainedValue()
                recorder.handleInput(inInputData, timestamp: now.pointee)
                return noErr
            },
            context,
            &procID
        )
        guard status == noErr, let procID else { throw RecorderError.ioProcCreationFailed(status) }

        let startStatus = AudioDeviceStart(aggregateID, procID)
        guard startStatus == noErr else { throw RecorderError.deviceStartFailed(startStatus) }
    }

    private func handleInput(_ bufferList: UnsafePointer<AudioBufferList>, timestamp: AudioTimeStamp) {
        guard isRecording, let file else { return }
        if firstBufferAt == nil {
            firstBufferAt = Date()
        }

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            bufferListNoCopy: bufferList
        ) else { return }

        queue.async {
            try? file.write(from: buffer)
        }
    }

    private func cleanup() {
        if let procID, aggregateID != kAudioObjectUnknown {
            AudioDeviceDestroyIOProcID(aggregateID, procID)
            self.procID = nil
        }
        if aggregateID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = AudioObjectID(kAudioObjectUnknown)
        }
        if tapID != AudioObjectID(kAudioObjectUnknown) {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
        file = nil
    }
}
