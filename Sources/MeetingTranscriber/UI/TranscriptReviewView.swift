import SwiftUI
import UniformTypeIdentifiers
import MeetingTranscriberCore

struct TranscriptReviewView: View {
    @ObservedObject var appState: AppState
    @State private var copiedToClipboard = false
    @State private var exportedURL: URL?
    @State private var isDragTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            if let transcript = appState.currentTranscript {
                // Header
                headerView(transcript: transcript)
                    .padding()
                    .background(Color(NSColor.windowBackgroundColor))

                Divider()

                // Speakers bar
                speakersVerificationSection(transcript: transcript)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

                Divider()

                // Transcript segments
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(transcript.segments) { segment in
                            segmentRow(segment: segment)
                        }
                    }
                    .padding()
                }

                Divider()

                // Action Footer
                footerView(transcript: transcript)
                    .padding()
                    .background(Color(NSColor.windowBackgroundColor))
            } else {
                emptyStateDropZone
            }
        }
        .frame(minWidth: 700, minHeight: 550)
        .dropDestination(for: URL.self) { items, _ in
            guard let url = items.first else { return false }
            let validExts = ["m4a", "mp3", "wav", "caf", "aac", "aiff", "flac", "ogg"]
            if validExts.contains(url.pathExtension.lowercased()) {
                appState.importAudioFile(url: url)
                return true
            }
            return false
        } isTargeted: { targeted in
            isDragTargeted = targeted
        }
    }

    // MARK: - Empty State / Drop Zone
    private var emptyStateDropZone: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(isDragTargeted ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: isDragTargeted ? "arrow.down.doc.fill" : "waveform.badge.mic")
                    .font(.system(size: 44))
                    .foregroundColor(.accentColor)
            }

            VStack(spacing: 6) {
                Text(isDragTargeted ? "Laat maar vallen!" : "Sleep audiobestand hierheen")
                    .font(.title3.bold())
                Text("Ondersteunt .m4a, .mp3, .wav, .caf, .aac — sprekers worden direct lokaal gescheiden.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            HStack(spacing: 12) {
                Button {
                    appState.selectAndTranscribeFile()
                } label: {
                    Label("Of kies een bestand...", systemImage: "folder")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isDragTargeted ? Color.accentColor : Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: isDragTargeted ? 3 : 2, dash: [8]))
                .padding(24)
        )
    }

    // MARK: - Header
    private func headerView(transcript: MeetingTranscript) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transcript.title)
                    .font(.title2.bold())
                HStack(spacing: 12) {
                    Label(formattedDate(transcript.date), systemImage: "calendar")
                    Label(ObsidianExporter.formatTimestamp(transcript.duration), systemImage: "clock")
                    Label("\(transcript.speakers.count) sprekers", systemImage: "person.2")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            Spacer()
            
            Button {
                appState.selectAndTranscribeFile()
            } label: {
                Label("Ander bestand...", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Speakers Verification Section
    private func speakersVerificationSection(transcript: MeetingTranscript) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sprekers & Stemprofielen")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(transcript.speakers) { speaker in
                        speakerCard(speaker: speaker)
                    }
                }
            }
        }
    }

    private func speakerCard(speaker: MeetingSpeaker) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(speaker.isConfirmed ? Color.green : (speaker.suggestedName != nil ? Color.blue : Color.orange))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(speaker.assignedName)
                        .font(.body.weight(.medium))
                    if speaker.isConfirmed {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                if let suggested = speaker.suggestedName, !speaker.isConfirmed {
                    Text("Match met \(suggested) (\(Int(speaker.confidence * 100))%)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else if speaker.embedding != nil {
                    Text("Stemprofiel actief")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if !speaker.isConfirmed && speaker.suggestedName != nil {
                Button("Bevestig") {
                    appState.updateSpeakerName(
                        speakerId: speaker.id,
                        newName: speaker.suggestedName!,
                        saveToProfile: true
                    )
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Button {
                    promptEditSpeaker(speaker: speaker)
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Segment Row
    private func segmentRow(segment: TranscriptSegment) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(segment.speakerName)
                    .font(.subheadline.bold())
                    .foregroundColor(.accentColor)
                Text("[\(ObsidianExporter.formatTimestamp(segment.start)) - \(ObsidianExporter.formatTimestamp(segment.end))]")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 140, alignment: .leading)

            Text(segment.text)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(6)
    }

    // MARK: - Footer
    private func footerView(transcript: MeetingTranscript) -> some View {
        HStack {
            if let exported = exportedURL {
                Label("Opgeslagen in Obsidian: \(exported.lastPathComponent)", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.subheadline)
            } else {
                Text(appState.statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                let md = ObsidianExporter.generateMarkdown(transcript: transcript)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(md, forType: .string)
                copiedToClipboard = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    copiedToClipboard = false
                }
            } label: {
                Label(copiedToClipboard ? "Gekopieerd!" : "Kopieer Markdown", systemImage: copiedToClipboard ? "checkmark" : "doc.on.doc")
            }

            Button {
                if let url = appState.exportCurrentTranscript() {
                    exportedURL = url
                }
            } label: {
                Label("Exporteer naar Obsidian", systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Helpers
    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    private func promptEditSpeaker(speaker: MeetingSpeaker) {
        let alert = NSAlert()
        alert.messageText = "Spreker hernoemen"
        alert.informativeText = "Voer de naam in voor \(speaker.label) en sla het stemprofiel op."
        alert.addButton(withTitle: "Opslaan")
        alert.addButton(withTitle: "Annuleren")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        input.stringValue = speaker.assignedName
        alert.accessoryView = input

        if alert.runModal() == .alertFirstButtonReturn {
            appState.updateSpeakerName(
                speakerId: speaker.id,
                newName: input.stringValue,
                saveToProfile: true
            )
        }
    }
}
