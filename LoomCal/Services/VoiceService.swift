import AVFoundation

/// Plays TTS audio from Convex storage URLs with play/pause controls.
/// Audio is generated server-side by the bridge — this service only handles playback.
@MainActor
class VoiceService: NSObject, ObservableObject {

    @Published var playingMessageId: String?   // Currently playing/paused message ID (nil = idle)
    @Published var isLoadingAudio: Bool = false // True while downloading audio from URL

    private var audioPlayer: AVAudioPlayer?
    private var audioCache: [String: Data] = [:] // In-memory cache keyed by message ID
    private var pausedMessageId: String?        // Message ID that was paused (for resume)

    // MARK: - Public API

    /// Toggle play/pause for a message. If a different message is playing, stops it first.
    func togglePlayPause(url: String, messageId: String) {
        if playingMessageId == messageId {
            if audioPlayer?.isPlaying == true {
                pause()
            } else {
                resume()
            }
        } else {
            play(url: url, messageId: messageId)
        }
    }

    /// Start playing audio for a message.
    func play(url: String, messageId: String) {
        // Stop any current playback
        stop()

        // Check cache first
        if let cached = audioCache[messageId] {
            startPlayback(data: cached, messageId: messageId)
            return
        }

        // Download from URL
        guard let audioURL = URL(string: url) else { return }
        isLoadingAudio = true

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: audioURL)
                self.audioCache[messageId] = data
                self.isLoadingAudio = false
                self.startPlayback(data: data, messageId: messageId)
            } catch {
                self.isLoadingAudio = false
            }
        }
    }

    /// Pause current playback (keeps position for resume).
    func pause() {
        audioPlayer?.pause()
        pausedMessageId = playingMessageId
    }

    /// Resume paused playback.
    func resume() {
        audioPlayer?.play()
    }

    /// Stop playback completely.
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        playingMessageId = nil
        pausedMessageId = nil
        isLoadingAudio = false
    }

    // MARK: - Private

    private func startPlayback(data: Data, messageId: String) {
        do {
            #if canImport(UIKit)
            try AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            #endif

            let player = try AVAudioPlayer(data: data)
            player.delegate = self
            player.play()
            audioPlayer = player
            playingMessageId = messageId
            pausedMessageId = nil
        } catch {
            playingMessageId = nil
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension VoiceService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.playingMessageId = nil
            self.pausedMessageId = nil
        }
    }
}
