# Bonzai Transcribe

Bonzai Transcribe is a native macOS application for fast, private, on-device audio recording, live transcription, and speaker diarization. Built with SwiftUI and Swift 6, powered by Apple Silicon hardware acceleration via CoreML and the Neural Engine.

---

## Features

- 🔒 **100% On-Device & Private**: All transcription and speaker diarization run locally via CoreML and Apple Neural Engine. No audio leaves your machine.
- 🎙️ **Dual & Application Audio Capture**: Capture your microphone alongside system audio, or target specific applications (Microsoft Teams, Zoom, Google Meet, Slack, etc.) using macOS ScreenCaptureKit.
- 👥 **Speaker Diarization & Management**: Automatically distinguish speakers with neural speaker clustering. Rename, merge, and organize speaker profiles across meetings.
- 🎧 **Interactive Review & Audio Playback**: Replay specific transcript segments or full recordings with synchronized word highlighting.
- 📝 **Markdown & Obsidian Export**: Export meeting notes, summaries, and speaker-attributed transcripts directly to Markdown / Obsidian vaults.
- ⚡ **Lightweight Menu Bar & Native Window**: Live status in the macOS menu bar with a full-featured desktop interface for review and history.

---

## Requirements

- **macOS 15.0 (Sequoia)** or later
- **Apple Silicon Mac** (M1/M2/M3/M4 recommended for real-time Neural Engine inference)
- **Xcode 16.0+** or **Swift 6.0+** toolchain

---

## Quick Start & Building

### 1. Clone the Repository

```bash
git clone https://github.com/<owner>/bonzai-transcribe.git
cd bonzai-transcribe
```

### 2. Build via Swift Package Manager

```bash
# Debug build
swift build

# Production / Release build
swift build -c release
```

### 3. Package as macOS App Bundle

A packaging script is provided to compile, bundle, and ad-hoc sign the application:

```bash
./scripts/package_app.sh
```

This generates `Bonzai Transcribe.app` in `/Applications` (or your local build output).

---

## Architecture & Technology Stack

- **UI Layer (`Sources/MeetingTranscriber`)**: SwiftUI (macOS HIG compliant), Combine, AppKit integration for menu bar and window lifecycle management.
- **Core Engine (`Sources/MeetingTranscriberCore`)**:
  - **Audio Engine**: `ScreenCaptureKit` and `AVFoundation` for low-latency multi-channel audio capture.
  - **Transcription & Diarization**: [FluidAudio](https://github.com/FluidInference/FluidAudio) CoreML integration for Parakeet ASR models and neural speaker embedding clustering.
  - **Storage & Exporters**: File-backed JSON store for transcripts and audio caches, with customizable Markdown and Obsidian exporters.

---

## Permissions

When running the application for the first time, macOS will request:
1. **Microphone**: To capture local voice input.
2. **Screen & System Audio Recording (ScreenCaptureKit)**: To capture audio from meeting apps (Teams, Zoom, browser, etc.).

---

## License

MIT License. See [LICENSE](LICENSE) for details.
