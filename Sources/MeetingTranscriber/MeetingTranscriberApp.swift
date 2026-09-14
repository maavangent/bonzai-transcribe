import SwiftUI
import MeetingTranscriberCore

@main
struct MeetingTranscriberApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // Menubar Interface
        MenuBarExtra {
            menuBarContent
        } label: {
            menuBarLabel
        }

        // Review Window
        Window("Meeting Transcript Review", id: "transcript-review") {
            TranscriptReviewView(appState: appState)
        }
        .defaultSize(width: 800, height: 600)

        // Speaker Profiles Window
        Window("Stemprofielen Beheren", id: "speaker-profiles") {
            SpeakerManagementView(appState: appState)
        }
        .defaultSize(width: 500, height: 400)
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

    @ViewBuilder
    private var menuBarContent: some View {
        VStack {
            switch appState.status {
            case .idle:
                Text("Klaar voor opname")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Divider()
                Button("Start Meeting Opname") {
                    appState.startRecording()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

            case .recording(let elapsed):
                Text("🔴 Opname actief: \(ObsidianExporter.formatTimestamp(elapsed))")
                    .font(.caption.bold())
                Divider()
                Button("Stop Opname & Transcribeer") {
                    appState.stopRecording()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

            case .transcribing(let stage):
                Text("⚡ Transcriberen...")
                    .font(.caption.bold())
                Text(stage)
                    .font(.caption2)
                    .foregroundColor(.secondary)

            case .reviewReady:
                Text("✅ Transcriptie gereed!")
                    .font(.caption.bold())
                Divider()
                Button("Open Transcript Review") {
                    openWindow(id: "transcript-review")
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }

            Divider()

            Button("Stemprofielen Beheren...") {
                openWindow(id: "speaker-profiles")
            }

            Divider()

            Button("Afsluiten") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
    }
}
