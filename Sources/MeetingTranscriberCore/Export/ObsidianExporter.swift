import Foundation

public struct ObsidianExporter {
    public static func formatTimestamp(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    public static func generateMarkdown(
        transcript: MeetingTranscript,
        vaultAttendeesWikilinks: Bool = true
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: transcript.date)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let timeStr = timeFormatter.string(from: transcript.date)

        // Unique speaker names
        let speakerNames = Array(Set(transcript.speakers.map { $0.assignedName })).sorted()

        var md = ""
        md += "---\n"
        md += "type: meeting\n"
        md += "date: \(dateStr)\n"
        md += "time: \"\(timeStr)\"\n"
        md += "duration: \"\(formatTimestamp(transcript.duration))\"\n"
        md += "attendees:\n"
        for name in speakerNames {
            if vaultAttendeesWikilinks {
                md += "  - \"[[\(name)]]\"\n"
            } else {
                md += "  - \(name)\n"
            }
        }
        md += "tags: [meeting, transcript, local-audio]\n"
        md += "---\n\n"

        md += "# \(dateStr) — \(transcript.title)\n\n"

        md += "## Sprekers in deze meeting\n"
        for speaker in transcript.speakers {
            let status = speaker.isConfirmed ? "Geverifieerd" : (speaker.suggestedName != nil ? "Voorgesteld (\(Int(speaker.confidence * 100))%)" : "Handmatig gelabeld")
            md += "- **\(speaker.assignedName)** (\(speaker.label) — \(status))\n"
        }
        md += "\n---\n\n"

        md += "## Transcript\n\n"
        for segment in transcript.segments {
            let start = formatTimestamp(segment.start)
            let end = formatTimestamp(segment.end)
            md += "**\(segment.speakerName)** [\(start) - \(end)]:\n"
            md += "\(segment.text)\n\n"
        }

        return md
    }

    public static func exportToVault(
        transcript: MeetingTranscript,
        destinationDir: URL = URL(fileURLWithPath: "/Users/maartenvangent/Obsidian/SecondBrain/_sources/Transcripts")
    ) throws -> URL {
        try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyMMdd"
        let dateCompact = dateFormatter.string(from: transcript.date)

        let sanitizedTitle = transcript.title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()

        let filename = "\(sanitizedTitle)-\(dateCompact).md"
        let fileURL = destinationDir.appendingPathComponent(filename)

        let markdown = generateMarkdown(transcript: transcript)
        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
