import SwiftUI
import MeetingTranscriberCore

@main
struct MeetingTranscriberApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        // Menubar Interface with Window Style (Live reactive popup)
        MenuBarExtra {
            MenuBarPopupView(appState: appState)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)

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
}
