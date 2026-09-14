import SwiftUI
import MeetingTranscriberCore

struct MainAppView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            sidebarView
        } detail: {
            TranscriptReviewView(appState: appState)
        }
        .frame(minWidth: 950, minHeight: 650)
    }

    // MARK: - Sidebar View
    private var sidebarView: some View {
        VStack(spacing: 0) {
            // Search Bar & Action Buttons
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Zoeken in meetings...", text: $appState.searchQuery)
                        .textFieldStyle(.plain)
                    if !appState.searchQuery.isEmpty {
                        Button {
                            appState.searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(7)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

                HStack(spacing: 8) {
                    Button {
                        appState.selectAndTranscribeFile()
                    } label: {
                        Label("Importeer", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        appState.startRecording()
                    } label: {
                        Label("Opnemen", systemImage: "record.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.small)
                }
            }
            .padding(12)

            Divider()

            // Transcripts List
            if appState.filteredTranscripts.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text(appState.searchQuery.isEmpty ? "Geen opnames gevonden" : "Geen resultaten")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Start een opname of importeer een bestand.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Spacer()
                }
            } else {
                List(selection: $appState.selectedTranscriptId) {
                    Section("Opnames (\(appState.filteredTranscripts.count))") {
                        ForEach(appState.filteredTranscripts) { transcript in
                            transcriptRow(transcript: transcript)
                                .tag(transcript.id)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        appState.deleteTranscript(id: transcript.id)
                                    } label: {
                                        Label("Verwijderen", systemImage: "trash")
                                    }
                                    Button {
                                        appState.selectedTranscriptId = transcript.id
                                        _ = appState.exportCurrentTranscript()
                                    } label: {
                                        Label("Exporteer naar Obsidian", systemImage: "arrow.up.forward.app")
                                    }
                                }
                        }
                    }
                }
                .listStyle(.sidebar)
            }

            Divider()

            // Bottom Settings / Profiles button
            HStack {
                Button {
                    WindowManager.shared.showSpeakerWindow(appState: appState)
                } label: {
                    Label("Stemprofielen beheren", systemImage: "person.2")
                }
                .buttonStyle(.plain)
                .font(.subheadline)
                .foregroundColor(.secondary)

                Spacer()

                Text("\(appState.speakerRegistry.allProfiles().count) stemmen")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 260, maxWidth: 320)
    }

    private func transcriptRow(transcript: MeetingTranscript) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(transcript.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Spacer()
                Text(ObsidianExporter.formatTimestamp(transcript.duration))
                    .font(.caption2.monospaced())
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 6) {
                Text(formattedDate(transcript.date))
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text("•").font(.caption2).foregroundColor(.secondary)

                // Speaker names badges
                Text(speakerSummary(transcript.speakers))
                    .font(.caption2)
                    .foregroundColor(.accentColor)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d MMM, HH:mm"
        return f.string(from: date)
    }

    private func speakerSummary(_ speakers: [MeetingSpeaker]) -> String {
        let names = speakers.map { $0.assignedName }
        if names.count <= 2 {
            return names.joined(separator: ", ")
        } else {
            return "\(names.prefix(2).joined(separator: ", ")) +\(names.count - 2)"
        }
    }
}
