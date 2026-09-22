import Foundation
import AppKit

public struct InstalledAudioApp: Identifiable, Hashable, Sendable {
    public let bundleIdentifier: String
    public let name: String
    public let path: String
    public let isRunning: Bool

    public var id: String { bundleIdentifier }
}

@MainActor
public final class InstalledAppCatalog: ObservableObject {
    @Published public private(set) var apps: [InstalledAudioApp] = []

    public init() {
        refresh()
    }

    public func refresh() {
        var appsByBundle: [String: InstalledAudioApp] = [:]
        let running = NSWorkspace.shared.runningApplications

        for app in running {
            guard let bundleID = app.bundleIdentifier,
                  let name = app.localizedName,
                  let path = app.bundleURL?.path,
                  isUserFacingApp(bundleID: bundleID, name: name) else { continue }
            appsByBundle[bundleID] = InstalledAudioApp(
                bundleIdentifier: bundleID,
                name: name,
                path: path,
                isRunning: true
            )
        }

        for directory in appDirectories {
            guard let urls = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in urls where url.pathExtension == "app" {
                guard let bundle = Bundle(url: url),
                      let bundleID = bundle.bundleIdentifier,
                      let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                        ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String),
                      isUserFacingApp(bundleID: bundleID, name: name),
                      appsByBundle[bundleID] == nil else { continue }
                appsByBundle[bundleID] = InstalledAudioApp(
                    bundleIdentifier: bundleID,
                    name: name,
                    path: url.path,
                    isRunning: false
                )
            }
        }

        apps = appsByBundle.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var appDirectories: [URL] {
        [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]
    }

    private func isUserFacingApp(bundleID: String, name: String) -> Bool {
        !bundleID.hasPrefix("com.apple.WebKit")
            && !bundleID.contains("Helper")
            && !bundleID.contains("XPC")
            && !name.contains("Content Synchronizer")
            && !name.contains("Crash Processor")
    }
}
