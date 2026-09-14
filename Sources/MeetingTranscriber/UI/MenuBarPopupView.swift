import SwiftUI
import MeetingTranscriberCore

struct MenuBarPopupView: View {
    @ObservedObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 12) {
            // Top Status Bar
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                    Text(statusTitle)
                        .font(.headline)
                }
                Spacer()
                if case .recording(let elapsed) = appState.status {
                    Text(ObsidianExporter.formatTimestamp(elapsed))
                        .font(.system(.body, design: .monospaced).bold())
                        .foregroundColor(.red)
                }
            }

            Text(appState.statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Main Action Button
            switch appState.status {
            case .idle:
                Button {
                    appState.startRecording()
                } label: {
                    HStack {
                        Image(systemName: "record.circle")
                        Text("Start Meeting Opname")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
                .keyboardShortcut("r", modifiers: [.command, .shift])

            case .recording:
                Button {
                    appState.stopRecording()
                } label: {
                    HStack {
                        Image(systemName: "stop.circle.fill")
                        Text("Stop Opname & Verwerk")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
                .keyboardShortcut("s", modifiers: [.command, .shift])

            case .transcribing:
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Bezig met verwerken...")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)

            case .reviewReady:
                Button {
                    openWindow(id: "transcript-review")
                } label: {
                    HStack {
                        Image(systemName: "doc.text.badge.plus")
                        Text("Open Transcript Review")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }

            Divider()

            // Quick Actions
            VStack(spacing: 6) {
                if appState.currentTranscript != nil {
                    Button {
                        openWindow(id: "transcript-review")
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("Laatste transcript bekijken")
                            Spacer()
                            Text("⇧⌘O").font(.caption2).foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    appState.selectAndTranscribeFile()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Audiobestand transcriberen...")
                        Spacer()
                    }
                }
                .buttonStyle(.plain)

                Button {
                    openWindow(id: "speaker-profiles")
                } label: {
                    HStack {
                        Image(systemName: "person.2")
                        Text("Stemprofielen beheren")
                        Spacer()
                    }
                }
                .buttonStyle(.plain)

                Divider()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    HStack {
                        Image(systemName: "power")
                        Text("Afsluiten")
                        Spacer()
                        Text("⌘Q").font(.caption2).foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .frame(width: 280)
    }

    private var statusColor: Color {
        switch appState.status {
        case .idle: return .gray
        case .recording: return .red
        case .transcribing: return .blue
        case .reviewReady: return .green
        }
    }

    private var statusTitle: String {
        switch appState.status {
        case .idle: return "Klaar voor opname"
        case .recording: return "Opname actief"
        case .transcribing: return "Transcriberen"
        case .reviewReady: return "Transcript gereed"
        }
    }
}
