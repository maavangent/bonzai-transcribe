import Foundation

public struct RecordingSessionInfo: Codable, Sendable {
    public let id: String
    public let startedAt: Date
    public var endedAt: Date?
    public let sessionDirectory: URL
    public let micAudioURL: URL
    public let systemAudioURL: URL
    public var micStartOffset: TimeInterval
    public var systemStartOffset: TimeInterval

    public init(
        id: String,
        startedAt: Date,
        endedAt: Date? = nil,
        sessionDirectory: URL,
        micAudioURL: URL,
        systemAudioURL: URL,
        micStartOffset: TimeInterval = 0.0,
        systemStartOffset: TimeInterval = 0.0
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.sessionDirectory = sessionDirectory
        self.micAudioURL = micAudioURL
        self.systemAudioURL = systemAudioURL
        self.micStartOffset = micStartOffset
        self.systemStartOffset = systemStartOffset
    }
}

public final class AudioCaptureCoordinator: @unchecked Sendable {
    public enum State: Sendable {
        case idle
        case recording(startedAt: Date, sessionDir: URL)
    }

    private let micRecorder = MicRecorder()
    private let systemRecorder = SystemAudioRecorder()
    private var currentSession: RecordingSessionInfo?
    private let baseStorageDir: URL

    public static let defaultRecordingsDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("MeetingTranscriber/Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        return appFolder
    }()

    public init(baseStorageDir: URL = AudioCaptureCoordinator.defaultRecordingsDirectory) {
        self.baseStorageDir = baseStorageDir
    }

    public var isRecording: Bool {
        micRecorder.isRecording || systemRecorder.isRecording
    }

    public func startSession(meetingTitle: String? = nil) throws -> RecordingSessionInfo {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestampStr = formatter.string(from: Date())
        
        let folderName = meetingTitle != nil ? "\(timestampStr)_\(meetingTitle!)" : timestampStr
        let sessionDir = baseStorageDir.appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)

        let micURL = sessionDir.appendingPathComponent("mic.caf")
        let sysURL = sessionDir.appendingPathComponent("system.caf")

        let startTime = Date()
        let session = RecordingSessionInfo(
            id: folderName,
            startedAt: startTime,
            sessionDirectory: sessionDir,
            micAudioURL: micURL,
            systemAudioURL: sysURL
        )

        try micRecorder.start(writingTo: micURL)
        do {
            try systemRecorder.start(writingTo: sysURL)
        } catch {
            print("⚠️ System audio tap failed to start (check permissions): \(error)")
        }

        self.currentSession = session
        return session
    }

    public func stopSession() -> RecordingSessionInfo? {
        guard var session = currentSession else { return nil }
        
        micRecorder.stop()
        systemRecorder.stop()

        let endTime = Date()
        session.endedAt = endTime

        let baseStart = session.startedAt
        if let micFirst = micRecorder.firstBufferAt {
            session.micStartOffset = max(0, micFirst.timeIntervalSince(baseStart))
        }
        if let sysFirst = systemRecorder.firstBufferAt {
            session.systemStartOffset = max(0, sysFirst.timeIntervalSince(baseStart))
        }

        // Save meta.json
        let metaURL = session.sessionDirectory.appendingPathComponent("meta.json")
        if let data = try? JSONEncoder().encode(session) {
            try? data.write(to: metaURL)
        }

        self.currentSession = nil
        return session
    }
}
