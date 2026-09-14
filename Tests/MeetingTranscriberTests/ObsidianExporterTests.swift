import XCTest
@testable import MeetingTranscriberCore

final class ObsidianExporterTests: XCTestCase {
    func testFormatTimestamp() {
        XCTAssertEqual(ObsidianExporter.formatTimestamp(0), "00:00")
        XCTAssertEqual(ObsidianExporter.formatTimestamp(65), "01:05")
        XCTAssertEqual(ObsidianExporter.formatTimestamp(3600), "60:00")
    }

    func testGenerateMarkdownStructure() {
        let speaker1 = MeetingSpeaker(
            id: "me",
            label: "Ik",
            assignedName: "Maarten van Gent",
            isConfirmed: true
        )
        let speaker2 = MeetingSpeaker(
            id: "system_0",
            label: "Spreker 1",
            assignedName: "Carsten",
            suggestedName: "Carsten",
            confidence: 0.92,
            isConfirmed: true
        )

        let segment1 = TranscriptSegment(
            speakerId: "me",
            speakerName: "Maarten van Gent",
            start: 0.0,
            end: 5.0,
            text: "Goedemorgen Carsten."
        )
        let segment2 = TranscriptSegment(
            speakerId: "system_0",
            speakerName: "Carsten",
            start: 5.5,
            end: 12.0,
            text: "Goedemorgen Maarten, laten we starten."
        )

        let transcript = MeetingTranscript(
            id: "2026-09-14-standup",
            title: "iO AI Enablement Standup",
            date: Date(),
            duration: 12.0,
            segments: [segment1, segment2],
            speakers: [speaker1, speaker2]
        )

        let md = ObsidianExporter.generateMarkdown(transcript: transcript)

        XCTAssertTrue(md.contains("type: meeting"))
        XCTAssertTrue(md.contains("[[Maarten van Gent]]"))
        XCTAssertTrue(md.contains("[[Carsten]]"))
        XCTAssertTrue(md.contains("**Maarten van Gent** [00:00 - 00:05]:"))
        XCTAssertTrue(md.contains("Goedemorgen Carsten."))
        XCTAssertTrue(md.contains("**Carsten** [00:05 - 00:12]:"))
    }
}
