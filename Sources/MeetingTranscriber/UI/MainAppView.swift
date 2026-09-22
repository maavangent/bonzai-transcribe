import SwiftUI
import MeetingTranscriberCore

struct MainAppView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            MeetingSidebar(appState: appState)
            Divider()
            TranscriptReviewView(appState: appState)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 980, minHeight: 650)
        .sheet(isPresented: $appState.showingCaptureSources) {
            CaptureProfilesView(appState: appState)
        }
        .sheet(isPresented: $appState.showingSpeakerProfiles) {
            SpeakerManagementView(appState: appState)
        }
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    appState.selectAndTranscribeFile()
                } label: {
                    Label("Importeer", systemImage: "square.and.arrow.down")
                }
                .help("Importeer een audiobestand")

                Button {
                    appState.toggleRecording()
                } label: {
                    Label(
                        appState.isRecording ? "Stop opname" : "Opnemen",
                        systemImage: appState.isRecording ? "stop.circle.fill" : "record.circle"
                    )
                }
                .tint(appState.isRecording ? .red : .accentColor)
                .help(appState.isRecording ? "Stop opname en verwerk" : "Start een opname")
            }
        }
    }
}
