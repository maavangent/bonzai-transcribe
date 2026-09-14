import Foundation
import AVFoundation
import Combine

@MainActor
public final class AudioPlayerManager: ObservableObject {
    public static let shared = AudioPlayerManager()

    @Published public var isPlaying: Bool = false
    @Published public var currentlyPlayingId: String? = nil

    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var stopTimer: Timer?

    public init() {}

    public func playAudio(from url: URL, startTime: TimeInterval, duration: TimeInterval? = nil, playbackId: String) {
        // If clicking the same playing item, pause it
        if isPlaying && currentlyPlayingId == playbackId {
            stop()
            return
        }

        stop()

        guard FileManager.default.fileExists(atPath: url.path) else {
            print("⚠️ Audio file not found at: \(url.path)")
            return
        }

        let playerItem = AVPlayerItem(url: url)
        self.player = AVPlayer(playerItem: playerItem)
        self.currentlyPlayingId = playbackId
        self.isPlaying = true

        let targetTime = CMTime(seconds: startTime, preferredTimescale: 600)
        player?.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor in
                self?.player?.play()
            }
        }

        // Auto-stop after duration if specified
        if let dur = duration, dur > 0 {
            stopTimer = Timer.scheduledTimer(withTimeInterval: dur, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    if self?.currentlyPlayingId == playbackId {
                        self?.stop()
                    }
                }
            }
        }

        // Notification when item finishes playing
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                if self?.currentlyPlayingId == playbackId {
                    self?.stop()
                }
            }
        }
    }

    public func stop() {
        stopTimer?.invalidate()
        stopTimer = nil
        player?.pause()
        player = nil
        isPlaying = false
        currentlyPlayingId = nil
    }
}
