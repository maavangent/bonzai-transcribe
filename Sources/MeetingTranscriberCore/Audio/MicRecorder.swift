import AVFoundation
import Foundation

public final class MicRecorder: @unchecked Sendable {
    public enum RecorderError: Error, CustomStringConvertible {
        case engineStartFailed(Error)
        case fileCreationFailed(Error)
        case formatUnsupported(AVAudioFormat)

        public var description: String {
            switch self {
            case .engineStartFailed(let e): return "mic engine start failed: \(e)"
            case .fileCreationFailed(let e): return "mic file creation failed: \(e)"
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

        if voiceProcessing {
            do {
                try input.setVoiceProcessingEnabled(true)
                input.voiceProcessingOtherAudioDuckingConfiguration =
                    .init(enableAdvancedDucking: false, duckingLevel: .min)
            } catch {
                print("⚠️ Mic voice processing unavailable (\(error)) — recording raw mic")
            }
        }
        let inputFormat = input.outputFormat(forBus: 0)

        guard let targetUrl = self.url else { return }
        
        let fileSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64000
        ]

        do {
            file = try AVAudioFile(
                forWriting: targetUrl,
                settings: fileSettings,
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )
        } catch {
            throw RecorderError.fileCreationFailed(error)
        }

        guard let mixer = AVAudioMixerNode() as AVAudioMixerNode? else { return }
        engine.attach(mixer)
        engine.connect(input, to: mixer, format: inputFormat)

        guard let format = file?.processingFormat else { return }

        mixer.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            guard let self = self, self.isRecording else { return }
            if self.firstBufferAt == nil {
                self.firstBufferAt = Date()
            }
            try? self.file?.write(from: buffer)
        }

        do {
            try engine.start()
        } catch {
            throw RecorderError.engineStartFailed(error)
        }
    }
}
