//
//  PlaybackController.swift
//  NotabilityClone
//
//  AVAudioPlayer wrapper for audio playback with time tracking
//

import Foundation
import AVFoundation

class PlaybackController: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var error: Error?
    
    private var audioPlayer: AVAudioPlayer?
    private var playbackUpdateTimer: Timer?
    
    func load(url: URL) {
        stop()
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.enableRate = true
            duration = audioPlayer?.duration ?? 0
            currentTime = 0
        } catch {
            self.error = error
        }
    }
    
    func play() {
        guard let player = audioPlayer else { return }
        guard !isPlaying else { return }
        
        player.play()
        isPlaying = true
        startUpdateTimer()
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopUpdateTimer()
    }
    
    func stop() {
        audioPlayer?.stop()
        isPlaying = false
        currentTime = 0
        stopUpdateTimer()
    }
    
    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else { return }
        player.currentTime = time
        currentTime = time
        
        if isPlaying {
            stopUpdateTimer()
            startUpdateTimer()
        }
    }
    
    private func startUpdateTimer() {
        stopUpdateTimer()
        playbackUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/15.0, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            DispatchQueue.main.async {
                self.currentTime = player.currentTime
            }
        }
    }
    
    private func stopUpdateTimer() {
        playbackUpdateTimer?.invalidate()
        playbackUpdateTimer = nil
    }
}

extension PlaybackController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.stopUpdateTimer()
            if flag {
                self.currentTime = self.duration
            }
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async {
            self.error = error ?? NSError(domain: "PlaybackController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Decode error"])
        }
    }
}