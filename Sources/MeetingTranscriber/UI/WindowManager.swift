import SwiftUI
import AppKit
import MeetingTranscriberCore

@MainActor
public final class WindowManager {
    public static let shared = WindowManager()

    private var mainWindow: NSWindow?
    private var speakerWindow: NSWindow?

    public func showMainWindow(appState: AppState) {
        NSApp.activate(ignoringOtherApps: true)

        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let contentView = MainAppView(appState: appState)
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Meeting Transcriber"
        window.contentViewController = hostingController
        window.center()
        window.setFrameAutosaveName("MeetingTranscriberMainWindow")
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        self.mainWindow = window
    }

    public func showSpeakerWindow(appState: AppState) {
        NSApp.activate(ignoringOtherApps: true)

        if let window = speakerWindow {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let contentView = SpeakerManagementView(appState: appState)
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 450),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Stemprofielen Beheren"
        window.contentViewController = hostingController
        window.center()
        window.setFrameAutosaveName("MeetingTranscriberSpeakerWindow")
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        self.speakerWindow = window
    }
}
