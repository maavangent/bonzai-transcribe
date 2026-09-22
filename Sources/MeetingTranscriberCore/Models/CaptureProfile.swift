import Foundation

public struct AudioSourceApp: Codable, Identifiable, Hashable, Sendable {
    public let bundleIdentifier: String
    public var name: String
    public var isEnabled: Bool

    public var id: String { bundleIdentifier }

    public init(bundleIdentifier: String, name: String, isEnabled: Bool = true) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.isEnabled = isEnabled
    }

    public static let defaults: [AudioSourceApp] = [
        AudioSourceApp(bundleIdentifier: "com.microsoft.teams2", name: "Microsoft Teams"),
        AudioSourceApp(bundleIdentifier: "com.tinyspeck.slackmacgap", name: "Slack"),
        AudioSourceApp(bundleIdentifier: "com.apple.Safari", name: "Safari", isEnabled: false),
        AudioSourceApp(bundleIdentifier: "com.google.Chrome", name: "Google Chrome", isEnabled: false),
        AudioSourceApp(bundleIdentifier: "com.brave.Browser", name: "Brave", isEnabled: false),
        AudioSourceApp(bundleIdentifier: "company.thebrowser.Browser", name: "Arc", isEnabled: false)
    ]
}

public final class AudioSourceStore: @unchecked Sendable {
    public static let shared = AudioSourceStore()
    private let fileURL: URL

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("MeetingTranscriber", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("audio-sources.json")
        }
    }

    public func load() -> [AudioSourceApp] {
        if let data = try? Data(contentsOf: fileURL),
           let sources = try? JSONDecoder().decode([AudioSourceApp].self, from: data),
           !sources.isEmpty {
            return sources
        }
        let sources = AudioSourceApp.defaults
        save(sources)
        return sources
    }

    public func save(_ sources: [AudioSourceApp]) {
        guard let data = try? JSONEncoder().encode(sources) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}

// Kept as a migration type for existing callers and old JSON data.
public struct CaptureProfile: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var apps: [AudioSourceApp]

    public init(id: UUID = UUID(), name: String, apps: [AudioSourceApp]) {
        self.id = id
        self.name = name
        self.apps = apps
    }
}

public final class CaptureProfileStore: @unchecked Sendable {
    public static let shared = CaptureProfileStore()
    private let fileURL: URL

    public init(fileURL: URL? = nil) {
        if let fileURL { self.fileURL = fileURL }
        else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("MeetingTranscriber", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("capture-profiles.json")
        }
    }

    public func load() -> [CaptureProfile] {
        guard let data = try? Data(contentsOf: fileURL),
              let profiles = try? JSONDecoder().decode([CaptureProfile].self, from: data) else { return [] }
        return profiles
    }

    public func save(_ profiles: [CaptureProfile]) {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
