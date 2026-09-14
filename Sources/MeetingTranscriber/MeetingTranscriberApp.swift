import SwiftUI
import AppKit
import MeetingTranscriberCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let appState = appState {
            WindowManager.shared.showMainWindow(appState: appState)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let appState = appState {
            WindowManager.shared.showMainWindow(appState: appState)
        }
        return true
    }
}

@main
struct MeetingTranscriberApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    init() {
        // App state will be attached in body
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopupView(appState: appState)
                .onAppear {
                    appDelegate.appState = appState
                }
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Audiobestand importeren...") {
                    appState.selectAndTranscribeFile()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Nieuwe opname starten") {
                    appState.startRecording()
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
        }
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        switch appState.status {
        case .idle:
            Image(systemName: "waveform.badge.mic")
        case .recording:
            Image(systemName: "record.circle.fill")
                .foregroundColor(.red)
        case .transcribing:
            Image(systemName: "arrow.triangle.2.circlepath")
        case .reviewReady:
            Image(systemName: "doc.text.badge.plus")
        }
    }
}
