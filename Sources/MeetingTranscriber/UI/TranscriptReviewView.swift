import SwiftUI
import MeetingTranscriberCore

struct TranscriptReviewView: View {
    @ObservedObject var appState: AppState
    @State private var copiedToClipboard = false
    @State private var exportedURL: URL?

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
                VStack(spacing: 12) {
                    Image(systemName: "waveform.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Geen actieve meeting transcriptie")
                        .font(.headline)
                    Text("Start een opname vanuit de menubalk om een transcript te genereren.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .frame(minWidth: 700, minHeight: 550)
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
