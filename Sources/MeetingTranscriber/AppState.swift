import Foundation
import SwiftUI
import AppKit
import MeetingTranscriberCore

@MainActor
public final class AppState: ObservableObject {
    public enum RecordingStatus: Equatable {
        case idle
        case recording(elapsed: TimeInterval)
        case transcribing(stage: String)
        case reviewReady
    }

    @Published public var status: RecordingStatus = .idle
    @Published public var transcripts: [MeetingTranscript] = []
    @Published public var selectedTranscriptId: String? = nil
    @Published public var searchQuery: String = ""
    @Published public var statusMessage: String = "Klaar voor opname"

    public var currentTranscript: MeetingTranscript? {
        get {
            if let id = selectedTranscriptId {
                return transcripts.first { $0.id == id }
            }
            return transcripts.first
        }
        set {
            guard let val = newValue else { return }
            if let idx = transcripts.firstIndex(where: { $0.id == val.id }) {
                transcripts[idx] = val
            } else {
                transcripts.insert(val, at: 0)
            }
            selectedTranscriptId = val.id
            TranscriptStore.shared.save(transcript: val)
        }
    }

    public var filteredTranscripts: [MeetingTranscript] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return transcripts }
        return transcripts.filter { t in
            t.title.lowercased().contains(q) ||
            t.speakers.contains { $0.assignedName.lowercased().contains(q) } ||
            t.segments.contains { $0.text.lowercased().contains(q) }
        }
    }

    public let speakerRegistry = SpeakerRegistry()
    private let audioCoordinator = AudioCaptureCoordinator()
    private let pipeline = TranscriptionPipeline()
    private var timer: Timer?
    private var recordingStartTime: Date?

    public init() {
        self.transcripts = TranscriptStore.shared.loadAll()
        self.selectedTranscriptId = self.transcripts.first?.id

        Task {
            statusMessage = "Modellen aan het voorbereiden..."
            do {
                try await pipeline.prepare()
                statusMessage = "Klaar voor opname"
            } catch {
                statusMessage = "Fout bij initialisatie: \(error.localizedDescription)"
            }
        }
    }

    public func toggleRecording(meetingTitle: String? = nil) {
        if case .recording = status {
            stopRecording()
        } else if case .idle = status {
            startRecording(meetingTitle: meetingTitle)
        }
    }

    public func startRecording(meetingTitle: String? = nil) {
        do {
            let session = try audioCoordinator.startSession(meetingTitle: meetingTitle)
            recordingStartTime = session.startedAt
            status = .recording(elapsed: 0)
            statusMessage = "Opname loopt..."

            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self, let start = self.recordingStartTime else { return }
                    let elapsed = Date().timeIntervalSince(start)
                    self.status = .recording(elapsed: elapsed)
                }
            }
        } catch {
            print("❌ Start recording failed: \(error)")
            statusMessage = "Kon opname niet starten: \(error)"
        }
    }

    public func stopRecording() {
        timer?.invalidate()
        timer = nil
        recordingStartTime = nil

        guard let session = audioCoordinator.stopSession() else {
            status = .idle
            statusMessage = "Geen actieve sessie gevonden."
            return
        }

        status = .transcribing(stage: "Parakeet v3 & Diarization...")
        statusMessage = "Bezig met lokale transcriptie & sprekerherkenning..."
        WindowManager.shared.showMainWindow(appState: self)

        Task {
            do {
                let transcript = try await pipeline.processSession(
                    session: session,
                    speakerRegistry: speakerRegistry
                )
                self.currentTranscript = transcript
                self.status = .reviewReady
                self.statusMessage = "Transcriptie voltooid!"
                WindowManager.shared.showMainWindow(appState: self)
            } catch {
                self.status = .idle
                self.statusMessage = "Fout tijdens transcriptie: \(error.localizedDescription)"
            }
        }
    }

    public func selectAndTranscribeFile() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false
            panel.allowedContentTypes = [.audio, .mp3, .mpeg4Audio, .wav, .aiff]
            panel.title = "Kies een audiobestand om te transcriberen"
            panel.level = .floating

            panel.begin { [weak self] response in
                guard let self = self else { return }
                if response == .OK, let url = panel.url {
                    Task { @MainActor in
                        self.importAudioFile(url: url)
                    }
                }
            }
        }
    }

    public func importAudioFile(url: URL) {
        status = .transcribing(stage: "Parakeet v3 & Diarization...")
        statusMessage = "Audiobestand transcriberen (\(url.lastPathComponent))..."
        WindowManager.shared.showMainWindow(appState: self)

        Task {
            do {
                let transcript = try await pipeline.processAudioFile(
                    url: url,
                    speakerRegistry: speakerRegistry
                )
                self.currentTranscript = transcript
                self.status = .reviewReady
                self.statusMessage = "Transcriptie voltooid voor: \(url.lastPathComponent)"
                WindowManager.shared.showMainWindow(appState: self)
            } catch {
                self.status = .idle
                self.statusMessage = "Fout bij bestandstranscriptie: \(error.localizedDescription)"
            }
        }
    }

    public func updateSpeakerName(speakerId: String, newName: String, saveToProfile: Bool = true) {
        guard var transcript = currentTranscript else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Update speaker in transcript
        if let idx = transcript.speakers.firstIndex(where: { $0.id == speakerId }) {
            transcript.speakers[idx].assignedName = trimmed
            transcript.speakers[idx].isConfirmed = true

            // Save or update profile in registry if embedding exists
            if saveToProfile, let embedding = transcript.speakers[idx].embedding {
                speakerRegistry.registerOrUpdate(name: trimmed, embedding: embedding)
            }
        }

        // Update segments referencing this speaker
        for i in 0..<transcript.segments.count {
            if transcript.segments[i].speakerId == speakerId {
                transcript.segments[i].speakerName = trimmed
            }
        }

        self.currentTranscript = transcript
    }

    public func deleteTranscript(id: String) {
        transcripts.removeAll { $0.id == id }
        TranscriptStore.shared.delete(id: id)
        if selectedTranscriptId == id {
            selectedTranscriptId = transcripts.first?.id
        }
    }

    public func exportCurrentTranscript() -> URL? {
        guard let transcript = currentTranscript else { return nil }
        do {
            let url = try ObsidianExporter.exportToVault(transcript: transcript)
            statusMessage = "Geëxporteerd naar: \(url.lastPathComponent)"
            return url
        } catch {
            statusMessage = "Export mislukt: \(error.localizedDescription)"
            return nil
        }
    }
}
