import AVFoundation
import FluidAudio
import Foundation

public final class TranscriptionPipeline: @unchecked Sendable {
    public enum PipelineError: Error, LocalizedError {
        case notPrepared
        case audioUnreadable(URL)
        case processingFailed(String)

        public var errorDescription: String? {
            switch self {
            case .notPrepared: return "Transcription pipeline has not been prepared."
            case .audioUnreadable(let url): return "Cannot read audio file at \(url.path)"
            case .processingFailed(let msg): return "Pipeline failure: \(msg)"
            }
        }
    }

    private var asrManager: AsrManager?
    private var diarizerManager: OfflineDiarizerManager?
    public private(set) var isReady = false

    public init() {}

    public func prepare() async throws {
        guard !isReady else { return }

        // 1. Prepare Parakeet v3 ASR
        let asrModels = try await AsrModels.downloadAndLoad(version: .v3)
        let asr = AsrManager()
        try await asr.loadModels(asrModels)
        self.asrManager = asr

        // 2. Prepare Offline Diarizer
        let diarizer = OfflineDiarizerManager()
        try await diarizer.prepareModels()
        self.diarizerManager = diarizer

        self.isReady = true
    }

    public func processSession(
        session: RecordingSessionInfo,
        speakerRegistry: SpeakerRegistry,
        mySpeakerName: String = "Maarten"
    ) async throws -> MeetingTranscript {
        guard isReady, let asrManager, let diarizerManager else {
            throw PipelineError.notPrepared
        }

        var allSegments: [TranscriptSegment] = []
        var meetingSpeakers: [MeetingSpeaker] = []

        // User's own voice
        let meSpeaker = MeetingSpeaker(
            id: "me",
            label: "Ik",
            assignedName: mySpeakerName,
            suggestedName: mySpeakerName,
            confidence: 1.0,
            isConfirmed: true
        )
        meetingSpeakers.append(meSpeaker)

        // 1. Process Mic track (Me)
        if FileManager.default.fileExists(atPath: session.micAudioURL.path),
           let probe = try? AVAudioFile(forReading: session.micAudioURL), probe.length > 0 {
            do {
                var decoderState = try TdtDecoderState()
                let result = try await asrManager.transcribe(session.micAudioURL, decoderState: &decoderState)
                let words = buildWordTimings(from: result.tokenTimings ?? [])
                
                let micSegments = buildSegmentsFromWords(
                    words: words,
                    timeOffset: session.micStartOffset,
                    speakerId: "me",
                    speakerName: mySpeakerName,
                    confidence: 1.0
                )
                allSegments.append(contentsOf: micSegments)
            } catch {
                print("⚠️ Failed to transcribe mic track: \(error)")
            }
        }

        // 2. Process System track (Teams / Other speakers)
        if FileManager.default.fileExists(atPath: session.systemAudioURL.path),
           let probe = try? AVAudioFile(forReading: session.systemAudioURL), probe.length > 0 {
            do {
                // Diarize system track
                let diarizationResult = try await diarizerManager.process(session.systemAudioURL)
                
                // Transcribe system track
                var decoderState = try TdtDecoderState()
                let asrResult = try await asrManager.transcribe(session.systemAudioURL, decoderState: &decoderState)
                let words = buildWordTimings(from: asrResult.tokenTimings ?? [])

                // Resolve speakers from Diarization Result
                let detectedSpeakers = extractSpeakers(
                    diarizationResult: diarizationResult,
                    speakerRegistry: speakerRegistry
                )
                meetingSpeakers.append(contentsOf: detectedSpeakers)

                // Align words with speaker segments
                let systemSegments = alignWordsWithDiarization(
                    words: words,
                    timeOffset: session.systemStartOffset,
                    diarizationSegments: diarizationResult.segments,
                    speakers: detectedSpeakers
                )
                allSegments.append(contentsOf: systemSegments)
            } catch {
                print("⚠️ Failed to process system track: \(error)")
            }
        }

        // 3. Sort all segments chronologically
        allSegments.sort { $0.start < $1.start }

        let duration = (session.endedAt ?? Date()).timeIntervalSince(session.startedAt)
        return MeetingTranscript(
            id: session.id,
            title: session.id,
            date: session.startedAt,
            duration: max(duration, allSegments.last?.end ?? 0.0),
            segments: allSegments,
            speakers: meetingSpeakers
        )
    }

    /// Process a standalone audio file (e.g. dropped/imported meeting recording)
    public func processAudioFile(
        url: URL,
        speakerRegistry: SpeakerRegistry,
        title: String? = nil
    ) async throws -> MeetingTranscript {
        guard isReady, let asrManager, let diarizerManager else {
            throw PipelineError.notPrepared
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PipelineError.audioUnreadable(url)
        }

        let meetingTitle = title ?? url.deletingPathExtension().lastPathComponent

        // 1. Run Core ML Speaker Diarization
        let diarizationResult = try await diarizerManager.process(url)

        // 2. Run Parakeet v3 ASR
        var decoderState = try TdtDecoderState()
        let asrResult = try await asrManager.transcribe(url, decoderState: &decoderState)
        let words = buildWordTimings(from: asrResult.tokenTimings ?? [])

        // 3. Extract & Match Speakers against Stored Profiles
        let detectedSpeakers = extractSpeakers(
            diarizationResult: diarizationResult,
            speakerRegistry: speakerRegistry
        )

        // 4. Align Words to Speakers
        let segments = alignWordsWithDiarization(
            words: words,
            timeOffset: 0.0,
            diarizationSegments: diarizationResult.segments,
            speakers: detectedSpeakers
        )

        let duration = segments.last?.end ?? 0.0

        return MeetingTranscript(
            id: UUID().uuidString,
            title: meetingTitle,
            date: Date(),
            duration: duration,
            segments: segments,
            speakers: detectedSpeakers
        )
    }

    // MARK: - Alignment & Segmentation Helpers

    private func extractSpeakers(
        diarizationResult: DiarizationResult,
        speakerRegistry: SpeakerRegistry
    ) -> [MeetingSpeaker] {
        var speakers: [MeetingSpeaker] = []
        let db = diarizationResult.speakerDatabase ?? [:]
        
        let uniqueSpeakerIds = Set(diarizationResult.segments.map { $0.speakerId }).sorted()

        for (index, spkId) in uniqueSpeakerIds.enumerated() {
            let label = "Spreker \(index + 1)"
            let embedding = db[spkId]
            
            var suggestedName: String? = nil
            var confidence: Float = 0.0
            var assignedName = label

            if let emb = embedding, let match = speakerRegistry.match(embedding: emb, threshold: 0.80) {
                suggestedName = match.profile.name
                assignedName = match.profile.name
                confidence = match.confidence
            }

            let spk = MeetingSpeaker(
                id: spkId,
                label: label,
                assignedName: assignedName,
                suggestedName: suggestedName,
                confidence: confidence,
                isConfirmed: suggestedName != nil,
                embedding: embedding
            )
            speakers.append(spk)
        }
        return speakers
    }

    private func alignWordsWithDiarization(
        words: [WordTiming],
        timeOffset: TimeInterval,
        diarizationSegments: [TimedSpeakerSegment],
        speakers: [MeetingSpeaker]
    ) -> [TranscriptSegment] {
        guard !words.isEmpty else { return [] }

        var alignedWordEntries: [(word: WordTiming, speaker: MeetingSpeaker)] = []
        let fallbackSpeaker = speakers.first ?? MeetingSpeaker(id: "system_unknown", label: "Spreker", assignedName: "Spreker")

        for word in words {
            let wordMid = (word.startTime + word.endTime) / 2.0
            // Find overlapping diarization segment
            let matchedDiarSeg = diarizationSegments.first { seg in
                wordMid >= Double(seg.startTimeSeconds) && wordMid <= Double(seg.endTimeSeconds)
            }
            
            let spkId = matchedDiarSeg?.speakerId ?? diarizationSegments.first?.speakerId ?? "unknown"
            let speaker = speakers.first { $0.id == spkId } ?? fallbackSpeaker
            alignedWordEntries.append((word, speaker))
        }

        // Group consecutive words by same speaker & sentence boundary
        var segments: [TranscriptSegment] = []
        var currentSpeaker = alignedWordEntries.first?.speaker
        var currentWords: [TranscriptWord] = []

        func flush(speaker: MeetingSpeaker?) {
            guard let spk = speaker, let first = currentWords.first, let last = currentWords.last else { return }
            let text = currentWords.map(\.word).joined(separator: " ")
            segments.append(TranscriptSegment(
                speakerId: spk.id,
                speakerName: spk.assignedName,
                confidence: spk.confidence,
                start: first.start,
                end: last.end,
                text: text,
                words: currentWords
            ))
            currentWords = []
        }

        for entry in alignedWordEntries {
            let shiftedWord = TranscriptWord(
                word: entry.word.word,
                start: entry.word.startTime + timeOffset,
                end: entry.word.endTime + timeOffset
            )

            if entry.speaker.id != currentSpeaker?.id {
                flush(speaker: currentSpeaker)
                currentSpeaker = entry.speaker
            }

            currentWords.append(shiftedWord)

            let endsSentence = shiftedWord.word.hasSuffix(".") || shiftedWord.word.hasSuffix("?") || shiftedWord.word.hasSuffix("!")
            if endsSentence || currentWords.count >= 50 {
                flush(speaker: currentSpeaker)
            }
        }
        flush(speaker: currentSpeaker)

        return segments
    }

    private func buildSegmentsFromWords(
        words: [WordTiming],
        timeOffset: TimeInterval,
        speakerId: String,
        speakerName: String,
        confidence: Float
    ) -> [TranscriptSegment] {
        var segments: [TranscriptSegment] = []
        var currentWords: [TranscriptWord] = []

        func flush() {
            guard let first = currentWords.first, let last = currentWords.last else { return }
            let text = currentWords.map(\.word).joined(separator: " ")
            segments.append(TranscriptSegment(
                speakerId: speakerId,
                speakerName: speakerName,
                confidence: confidence,
                start: first.start,
                end: last.end,
                text: text,
                words: currentWords
            ))
            currentWords = []
        }

        for word in words {
            let shifted = TranscriptWord(
                word: word.word,
                start: word.startTime + timeOffset,
                end: word.endTime + timeOffset
            )

            if let last = currentWords.last, shifted.start - last.end > 1.2 {
                flush()
            }
            currentWords.append(shifted)

            let endsSentence = shifted.word.hasSuffix(".") || shifted.word.hasSuffix("?") || shifted.word.hasSuffix("!")
            if endsSentence || currentWords.count >= 50 {
                flush()
            }
        }
        flush()
        return segments
    }
}
