import SwiftUI
import UniformTypeIdentifiers
import MeetingTranscriberCore

struct TranscriptReviewView: View {
    @ObservedObject var appState: AppState
    @StateObject private var audioPlayer = AudioPlayerManager.shared
    @State private var copiedToClipboard = false
    @State private var exportedURL: URL?
    @State private var isDragTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            if case .transcribing(let stage) = appState.status {
                // Active Transcription Progress Screen
                transcribingProgressView(stage: stage)
            } else if let transcript = appState.currentTranscript {
                // Header and speaker verification
                VStack(alignment: .leading, spacing: 0) {
                    headerView(transcript: transcript)
                        .padding(.horizontal, 24)
                        .padding(.top, 22)
                        .padding(.bottom, 16)

                    Divider()

                    speakersVerificationSection(transcript: transcript)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                }
                .background(Color(nsColor: .windowBackgroundColor))

                Divider()

                // Transcript segments with consolidated text & playback
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(transcript.segments) { segment in
                        segmentRow(segment: segment, sourceAudioURL: transcript.sourceAudioURL)
                    }
                }
                .frame(maxWidth: 900, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
            }
            .background(Color(nsColor: .textBackgroundColor))

                Divider()

                // Action Footer
                footerView(transcript: transcript)
                    .padding()
                    .background(Color(NSColor.windowBackgroundColor))
            } else {
                emptyStateDropZone
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dropDestination(for: URL.self) { items, _ in
            guard let url = items.first else { return false }
            let validExts = ["m4a", "mp3", "wav", "caf", "aac", "aiff", "flac", "ogg", "qta"]
            if validExts.contains(url.pathExtension.lowercased()) {
                appState.importAudioFile(url: url)
                return true
            }
            return false
        } isTargeted: { targeted in
            isDragTargeted = targeted
        }
    }

    // MARK: - Transcribing Progress Screen
    private func transcribingProgressView(stage: String) -> some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 6)
                    .frame(width: 80, height: 80)
                
                ProgressView()
                    .scaleEffect(1.5)
            }

            VStack(spacing: 8) {
                Text("Meeting Wordt Verwerkt...")
                    .font(.title2.bold())
                Text(appState.statusMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 450)
            }

            HStack(spacing: 16) {
                Label("Parakeet v3 ASR", systemImage: "bolt.fill")
                Text("•").foregroundColor(.secondary)
                Label("PyAnnote Diarization", systemImage: "person.2.fill")
                Text("•").foregroundColor(.secondary)
                Label("Apple Neural Engine", systemImage: "cpu.fill")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
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

    // MARK: - Speakers Verification Section with Audio Preview
    private func speakersVerificationSection(transcript: MeetingTranscript) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
            Text("Sprekers")
                    .font(.headline)
                Spacer()
                if transcript.speakers.contains(where: { !$0.isConfirmed }) {
                    Button("Verifieer") {
                        appState.showingSpeakerProfiles = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(transcript.speakers) { speaker in
                        speakerCard(speaker: speaker, sourceAudioURL: transcript.sourceAudioURL)
                    }
                }
            }
        }
    }

    private func speakerCard(speaker: MeetingSpeaker, sourceAudioURL: URL?) -> some View {
        let isCurrentlyPlaying = audioPlayer.isPlaying && audioPlayer.currentlyPlayingId == "speaker_\(speaker.id)"

        return HStack(spacing: 10) {
            // Play Audio Sample Button
            if let audioURL = sourceAudioURL, let start = speaker.sampleStart {
                Button {
                    let dur = min(speaker.sampleDuration ?? 6.0, 8.0)
                    audioPlayer.playAudio(
                        from: audioURL,
                        startTime: start,
                        duration: max(3.0, dur),
                        playbackId: "speaker_\(speaker.id)"
                    )
                } label: {
                    Image(systemName: isCurrentlyPlaying ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title3)
                        .foregroundColor(isCurrentlyPlaying ? .red : .accentColor)
                }
                .buttonStyle(.plain)
                .help("Beluister fragment van \(speaker.assignedName)")
            } else {
                Circle()
                    .fill(speaker.isConfirmed ? Color.green : (speaker.suggestedName != nil ? Color.blue : Color.orange))
                    .frame(width: 10, height: 10)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(speaker.assignedName)
                    .font(.body.weight(.medium))
                if speaker.isConfirmed {
                    Label("Bevestigd", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if let suggested = speaker.suggestedName {
                    Text("Voorstel: \(suggested) · \(Int(speaker.confidence * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Nog niet herkend")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let suggested = speaker.suggestedName, !speaker.isConfirmed {
                Button("Bevestig") {
                    appState.updateSpeakerName(
                        speakerId: speaker.id,
                        newName: suggested,
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
                .help("Naam wijzigen")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isCurrentlyPlaying ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isCurrentlyPlaying ? 2 : 1)
        )
    }

    // MARK: - Consolidated Segment Row with Audio Playback
    private func segmentRow(segment: TranscriptSegment, sourceAudioURL: URL?) -> some View {
        let isPlayingSegment = audioPlayer.isPlaying && audioPlayer.currentlyPlayingId == "seg_\(segment.id)"

        return HStack(alignment: .top, spacing: 14) {
            // Speaker Name & Timestamp & Play button
            HStack(spacing: 6) {
                if let audioURL = sourceAudioURL {
                    Button {
                        audioPlayer.playAudio(
                            from: audioURL,
                            startTime: segment.start,
                            duration: segment.end - segment.start,
                            playbackId: "seg_\(segment.id)"
                        )
                    } label: {
                        Image(systemName: isPlayingSegment ? "stop.circle.fill" : "play.circle")
                            .font(.body)
                            .foregroundColor(isPlayingSegment ? .red : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Beluister deze alinea")
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(segment.speakerName)
                        .font(.subheadline.bold())
                        .foregroundColor(.accentColor)
                    Text("[\(ObsidianExporter.formatTimestamp(segment.start)) - \(ObsidianExporter.formatTimestamp(segment.end))]")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 170, alignment: .leading)

            // Spoken text (clean paragraph)
            Text(segment.text)
                .font(.body)
                .lineSpacing(4)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(isPlayingSegment ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor).opacity(0.35))
        .cornerRadius(8)
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
