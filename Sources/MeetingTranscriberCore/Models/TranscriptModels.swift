import Foundation

public struct TranscriptWord: Codable, Sendable {
    public var word: String
    public var start: TimeInterval
    public var end: TimeInterval

    public init(word: String, start: TimeInterval, end: TimeInterval) {
        self.word = word
        self.start = start
        self.end = end
    }
}

public struct TranscriptSegment: Codable, Identifiable, Sendable {
    public var id: UUID
    public var speakerId: String
    public var speakerName: String
    public var confidence: Float
    public var start: TimeInterval
    public var end: TimeInterval
    public var text: String
    public var words: [TranscriptWord]

    public init(
        id: UUID = UUID(),
        speakerId: String,
        speakerName: String,
        confidence: Float = 1.0,
        start: TimeInterval,
        end: TimeInterval,
        text: String,
        words: [TranscriptWord] = []
    ) {
        self.id = id
        self.speakerId = speakerId
        self.speakerName = speakerName
        self.confidence = confidence
        self.start = start
        self.end = end
        self.text = text
        self.words = words
    }
}

public struct MeetingSpeaker: Codable, Identifiable, Sendable {
    public var id: String // e.g. "mic_me", "system_spk0", "system_spk1"
    public var label: String // e.g. "Spreker 1"
    public var assignedName: String // e.g. "Carsten"
    public var suggestedName: String? // e.g. "Carsten"
    public var confidence: Float // e.g. 0.91
    public var isConfirmed: Bool
    public var embedding: [Float]?
    public var sampleStart: TimeInterval? // Timestamp of a representative clean speech sample
    public var sampleDuration: TimeInterval?

    public init(
        id: String,
        label: String,
        assignedName: String,
        suggestedName: String? = nil,
        confidence: Float = 1.0,
        isConfirmed: Bool = false,
        embedding: [Float]? = nil,
        sampleStart: TimeInterval? = nil,
        sampleDuration: TimeInterval? = nil
    ) {
        self.id = id
        self.label = label
        self.assignedName = assignedName
        self.suggestedName = suggestedName
        self.confidence = confidence
        self.isConfirmed = isConfirmed
        self.embedding = embedding
        self.sampleStart = sampleStart
        self.sampleDuration = sampleDuration
    }
}

public struct MeetingTranscript: Codable, Identifiable, Sendable {
    public let id: String
    public var title: String
    public let date: Date
    public var duration: TimeInterval
    public var segments: [TranscriptSegment]
    public var speakers: [MeetingSpeaker]
    public var sourceAudioURL: URL?

    public init(
        id: String,
        title: String,
        date: Date = Date(),
        duration: TimeInterval = 0.0,
        segments: [TranscriptSegment] = [],
        speakers: [MeetingSpeaker] = [],
        sourceAudioURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.duration = duration
        self.segments = segments
        self.speakers = speakers
        self.sourceAudioURL = sourceAudioURL
    }
}
