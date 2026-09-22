import SwiftUI
import MeetingTranscriberCore

struct MeetingSidebar: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader
            Divider()

            if appState.filteredTranscripts.isEmpty {
                emptyState
            } else {
                transcriptList
            }

            Divider()
            managementFooter
        }
        .frame(width: 280)
        .background(Color(nsColor: .controlBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Meetingnavigatie")
    }

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.badge.mic")
                    .font(.title3)
                    .foregroundStyle(.tint)
                Text("Bonzai Transcribe")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Zoek in meetings", text: $appState.searchQuery)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Zoek in meetings")

                if !appState.searchQuery.isEmpty {
                    Button {
                        appState.searchQuery = ""
                    } label: {
                        Label("Wis zoekopdracht", systemImage: "xmark.circle.fill")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .padding(12)
    }

    private var transcriptList: some View {
        List(selection: $appState.selectedTranscriptId) {
            Section {
                ForEach(appState.filteredTranscripts) { transcript in
                    MeetingSidebarRow(transcript: transcript)
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
            } header: {
                HStack {
                    Text("OPNAMES")
                    Spacer()
                    Text("\(appState.filteredTranscripts.count)")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                appState.searchQuery.isEmpty ? "Geen opnames" : "Geen resultaten",
                systemImage: appState.searchQuery.isEmpty ? "waveform" : "magnifyingglass"
            )
        } description: {
            Text(appState.searchQuery.isEmpty
                 ? "Start een opname of importeer een audiobestand."
                 : "Probeer een andere zoekopdracht.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var managementFooter: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("BEHEER")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            HStack(spacing: 4) {
                Button {
                    appState.showingSpeakerProfiles = true
                } label: {
                    Label("Stemprofielen", systemImage: "person.2")
                }
                .help("Beheer opgeslagen stemprofielen")

                Spacer(minLength: 0)

                Button {
                    appState.showingCaptureSources = true
                } label: {
                    Label("Opnamebronnen", systemImage: "waveform.badge.plus")
                }
                .help("Beheer opnamebronnen")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .padding(10)
    }
}

private struct MeetingSidebarRow: View {
    let transcript: MeetingTranscript

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(.tint)
                    .frame(width: 6, height: 6)

                Text(transcript.title)
                    .lineLimit(1)
                    .font(.body.weight(.medium))

                Spacer(minLength: 4)

                Text(ObsidianExporter.formatTimestamp(transcript.duration))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 5) {
                Text(transcript.date, format: .dateTime.day().month(.abbreviated).hour().minute())
                Text("·")
                Text(speakerSummary)
                    .lineLimit(1)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.leading, 12)
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(transcript.title), \(speakerSummary), duur \(ObsidianExporter.formatTimestamp(transcript.duration))")
    }

    private var speakerSummary: String {
        let names = transcript.speakers.map(\.assignedName)
        if names.count <= 2 {
            return names.joined(separator: ", ")
        }
        return "\(names.prefix(2).joined(separator: ", ")) +\(names.count - 2)"
    }
}
