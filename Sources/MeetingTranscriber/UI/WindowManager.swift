import SwiftUI
import AppKit
import MeetingTranscriberCore

@MainActor
public final class WindowManager {
    public static let shared = WindowManager()

    private var reviewWindow: NSWindow?
    private var speakerWindow: NSWindow?

    public func showReviewWindow(appState: AppState) {
        NSApp.activate(ignoringOtherApps: true)

        if let window = reviewWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let contentView = TranscriptReviewView(appState: appState)
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 850, height: 650),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Meeting Transcript Review"
        window.contentViewController = hostingController
        window.center()
        window.setFrameAutosaveName("MeetingTranscriberReviewWindow")
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        self.reviewWindow = window
    }

    public func showSpeakerWindow(appState: AppState) {
        NSApp.activate(ignoringOtherApps: true)

        if let window = speakerWindow, window.isVisible {
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
