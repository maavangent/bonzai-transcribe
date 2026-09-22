import SwiftUI
import AppKit
import MeetingTranscriberCore

@MainActor
public final class WindowManager {
    public static let shared = WindowManager()

    private var mainWindow: NSWindow?
    private var speakerWindow: NSWindow?
    private var captureProfilesWindow: NSWindow?

    public func showMainWindowIfNeeded(appState: AppState) {
        guard mainWindow == nil else { return }
        showMainWindow(appState: appState)
    }

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
        window.identifier = NSUserInterfaceItemIdentifier("BonzaiTranscribeMainWindow")
        window.title = "Bonzai Transcribe"
        window.contentViewController = hostingController
        window.setFrameAutosaveName("BonzaiTranscribeMainWindow")
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        self.mainWindow = window
    }

    public func showCaptureProfilesWindow(appState: AppState) {
        NSApp.activate(ignoringOtherApps: true)
        if let window = captureProfilesWindow {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hostingController = NSHostingController(rootView: CaptureProfilesView(appState: appState))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Opnamebronnen — Bonzai Transcribe"
        window.contentViewController = hostingController
        window.center()
        window.setFrameAutosaveName("BonzaiTranscribeCaptureProfilesWindow")
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        captureProfilesWindow = window
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
        window.title = "Bonzai Transcribe"
        window.contentViewController = hostingController
        window.center()
        window.setFrameAutosaveName("BonzaiTranscribeSpeakerWindow")
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        self.speakerWindow = window
    }
}
