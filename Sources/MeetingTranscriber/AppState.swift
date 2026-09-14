import Foundation
import SwiftUI
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
    @Published public var currentTranscript: MeetingTranscript?
    @Published public var statusMessage: String = "Klaar voor opname"
    @Published public var isReviewWindowOpen: Bool = false
    @Published public var recentTranscripts: [MeetingTranscript] = []

    public let speakerRegistry = SpeakerRegistry()
    private let audioCoordinator = AudioCaptureCoordinator()
    private let pipeline = TranscriptionPipeline()
    private var timer: Timer?
    private var recordingStartTime: Date?

    public init() {
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
            statusMessage = "Kon opname niet starten: \(error.localizedDescription)"
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

        Task {
            do {
                let transcript = try await pipeline.processSession(
                    session: session,
                    speakerRegistry: speakerRegistry
                )
                self.currentTranscript = transcript
                self.status = .reviewReady
                self.statusMessage = "Transcriptie voltooid!"
                self.isReviewWindowOpen = true
            } catch {
                self.status = .idle
                self.statusMessage = "Fout tijdens transcriptie: \(error.localizedDescription)"
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
