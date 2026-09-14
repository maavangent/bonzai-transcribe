import SwiftUI
import MeetingTranscriberCore

@main
struct MeetingTranscriberApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopupView(appState: appState)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
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
