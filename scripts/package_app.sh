#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DIR"

echo "🔨 Building MeetingTranscriber (Release)..."
swift build -c release

APP_DIR="/Applications/MeetingTranscriber.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📦 Creating App Bundle at $APP_DIR..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp .build/release/MeetingTranscriber "$MACOS_DIR/MeetingTranscriber"
cp Sources/MeetingTranscriber/Info.plist "$CONTENTS_DIR/Info.plist"

echo "✅ Successfully packaged MeetingTranscriber.app!"
