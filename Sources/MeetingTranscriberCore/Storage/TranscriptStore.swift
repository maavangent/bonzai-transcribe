import Foundation

public final class TranscriptStore: @unchecked Sendable {
    public static let shared = TranscriptStore()

    public let storageDir: URL

    public init(storageDir: URL? = nil) {
        if let dir = storageDir {
            self.storageDir = dir
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appFolder = appSupport.appendingPathComponent("MeetingTranscriber/Transcripts", isDirectory: true)
            try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
            self.storageDir = appFolder
        }
    }

    public func save(transcript: MeetingTranscript) {
        let fileURL = storageDir.appendingPathComponent("\(transcript.id).json")
        do {
            let data = try JSONEncoder().encode(transcript)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("❌ Failed to save transcript \(transcript.id): \(error)")
        }
    }

    public func loadAll() -> [MeetingTranscript] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: storageDir, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return []
        }

        var loaded: [MeetingTranscript] = []
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let transcript = try? JSONDecoder().decode(MeetingTranscript.self, from: data) {
                loaded.append(transcript)
            }
        }

        return loaded.sorted { $0.date > $1.date }
    }

    public func delete(id: String) {
        let fileURL = storageDir.appendingPathComponent("\(id).json")
        try? FileManager.default.removeItem(at: fileURL)
    }
}
