//
//  SpotifyPlaybackTimeSource.swift
//  VeloCue
//
//  Created by Sebastian Skora on 2025.
//  Real Spotify time source - syncs with actual Spotify playback.
//

import Foundation
import Observation

// real Spotify time source - reads actual playback position from Spotify
// this is the "production" version that coaches use in real classes
@MainActor
@Observable
final class SpotifyPlaybackTimeSource: PlaybackTimeSource {
    let spotifyService: SpotifyService
    nonisolated(unsafe) private var observationTask: Task<Void, Never>?
    
    // store as properties so @Observable can track changes for SwiftUI
    private(set) var currentTime: Int = 0
    private(set) var isPlaying: Bool = false
    
    // local timer state for smooth updates - Spotify API is laggy so we interpolate
    private var localTime: Int = 0
    private var lastSyncTime: Date?
    private var lastSyncPosition: Int = 0
    
    init(spotifyService: SpotifyService) {
        self.spotifyService = spotifyService
        startObserving()
    }
    
    private func startObserving() {
        observationTask?.cancel()
        
        // use local timer for smooth updates, sync with Spotify every 1 second
        // Spotify API is slow so we interpolate between sync points for smooth UI
        observationTask = Task { @MainActor in
            while !Task.isCancelled {
                let now = Date()
                
                // sync with Spotify every 1 second for accuracy
                if let lastSync = lastSyncTime, now.timeIntervalSince(lastSync) >= 1.0 {
                    // sync: grab real position from Spotify
                    let spotifyPosition = spotifyService.currentPosition
                    localTime = spotifyPosition
                    lastSyncPosition = spotifyPosition
                    lastSyncTime = now
                    currentTime = localTime
                    isPlaying = spotifyService.isPlaying
                } else if lastSyncTime == nil {
                    // first sync - get initial position
                    let spotifyPosition = spotifyService.currentPosition
                    localTime = spotifyPosition
                    lastSyncPosition = spotifyPosition
                    lastSyncTime = now
                    currentTime = localTime
                    isPlaying = spotifyService.isPlaying
                } else if isPlaying {
                    // smooth local increment between syncs - interpolate time
                    if let lastSync = lastSyncTime {
                        let elapsed = now.timeIntervalSince(lastSync)
                        // use precise elapsed time for smooth updates
                        localTime = lastSyncPosition + Int(elapsed.rounded())
                        currentTime = localTime
                    }
                } else {
                    // not playing - just use Spotify's position directly
                    currentTime = spotifyService.currentPosition
                    isPlaying = spotifyService.isPlaying
                }
                
                // update playing state from Spotify (can change anytime)
                isPlaying = spotifyService.isPlaying
                
                // update every 0.1 seconds for smooth UI updates
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }
    
    func play() {
        // read-only mode for now - TODO: implement Spotify control later
        // In future milestone, this would call spotifyService.play()
    }
    
    func pause() {
        // read-only mode for now - TODO: implement Spotify control later
        // In future milestone, this would call spotifyService.pause()
    }
    
    func seek(to time: Int) {
        // read-only mode for now - TODO: implement Spotify control later
        // In future milestone, this would call spotifyService.seek(to: time)
    }
    
    deinit {
        observationTask?.cancel() // cleanup - don't leak tasks
    }
}

