import AVFoundation
import Foundation

public final class MicRecorder: @unchecked Sendable {
    public enum RecorderError: Error, CustomStringConvertible {
        case engineStartFailed(Error)
        case fileCreationFailed(Error)
        case formatUnsupported(AVAudioFormat)

        public var description: String {
            switch self {
            case .engineStartFailed(let e): return "mic engine start failed: \(e.localizedDescription)"
            case .fileCreationFailed(let e): return "mic file creation failed: \(e.localizedDescription)"
            case .formatUnsupported(let f): return "can't downmix mic format \(f)"
            }
        }
    }

    private var engine = AVAudioEngine()
    private var file: AVAudioFile?
    private var url: URL?
    public private(set) var isRecording = false
    public private(set) var firstBufferAt: Date?

    public init() {}

    public func start(writingTo url: URL, voiceProcessing: Bool = false) throws {
        guard !isRecording else { return }
        self.url = url
        try attach(voiceProcessing: voiceProcessing)
        isRecording = true
    }

    public func stop() {
        guard isRecording else { return }
        isRecording = false
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        file = nil
    }

    private func attach(voiceProcessing: Bool) throws {
        engine = AVAudioEngine()
        let input = engine.inputNode

        var voice = voiceProcessing
        if voice {
            do {
                try input.setVoiceProcessingEnabled(true)
                input.voiceProcessingOtherAudioDuckingConfiguration =
                    .init(enableAdvancedDucking: false, duckingLevel: .min)
            } catch {
                print("⚠️ Mic voice processing unavailable (\(error)) — recording raw mic")
                voice = false
            }
        }
        let inputFormat = input.outputFormat(forBus: 0)

        guard let monoFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: inputFormat.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw RecorderError.formatUnsupported(inputFormat)
        }

        guard let targetUrl = self.url else { return }

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: monoFormat.sampleRate,
            AVNumberOfChannelsKey: 1,
        ]

        do {
            file = try AVAudioFile(
                forWriting: targetUrl,
                settings: settings,
                commonFormat: monoFormat.commonFormat,
                interleaved: monoFormat.isInterleaved
            )
        } catch {
            throw RecorderError.fileCreationFailed(error)
        }

        if voice {
            engine.connect(engine.mainMixerNode, to: engine.outputNode, format: monoFormat)
            input.installTap(onBus: 0, bufferSize: 4096, format: monoFormat) { [weak self] buffer, _ in
                guard let self = self, let file = self.file else { return }
                if self.firstBufferAt == nil { self.firstBufferAt = Date() }
                try? file.write(from: buffer)
            }
        } else {
            guard let converter = AVAudioConverter(from: inputFormat, to: monoFormat) else {
                throw RecorderError.formatUnsupported(inputFormat)
            }
            input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
                guard let self = self, let file = self.file else { return }
                if self.firstBufferAt == nil { self.firstBufferAt = Date() }
                guard let mono = AVAudioPCMBuffer(
                    pcmFormat: monoFormat,
                    frameCapacity: buffer.frameCapacity
                ) else { return }
                do {
                    var error: NSError?
                    converter.convert(to: mono, error: &error) { _, outStatus in
                        outStatus.pointee = .haveData
                        return buffer
                    }
                    try file.write(from: mono)
                } catch {
                    print("⚠️ Mic write error: \(error)")
                }
            }
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            file = nil
            throw RecorderError.engineStartFailed(error)
        }
    }
}
