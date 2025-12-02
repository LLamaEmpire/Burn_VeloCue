//
//  SimulatedPlaybackTimeSource.swift
//  VeloCue
//
//  Created by Sebastian Skora on 2025.
//  Fake time source for development - no Spotify required.
//

import Foundation
import SwiftUI
import Observation

// timer-based playback for development - nobody wants to wait 3 minutes to test timing
@MainActor
@Observable
final class SimulatedPlaybackTimeSource: PlaybackTimeSource {
    private(set) var currentTime: Int = 0
    private(set) var isPlaying: Bool = false
    
    nonisolated(unsafe) private var timer: Timer?
    private let updateInterval: TimeInterval = 0.1  // update 10 times per second for smooth UI
    private var accumulatedTime: TimeInterval = 0  // track fractional seconds
    private var lastUpdateTime: Date?
    
    func play() {
        guard !isPlaying else { return }
        isPlaying = true
        lastUpdateTime = Date()
        
        // start the timer - this is what drives the "playback"
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            Task { @MainActor in
                let now = Date()
                if let last = self.lastUpdateTime {
                    // accumulate time but only increment seconds when we have a full second
                    self.accumulatedTime += now.timeIntervalSince(last)
                    if self.accumulatedTime >= 1.0 {
                        self.currentTime += Int(self.accumulatedTime)
                        self.accumulatedTime = self.accumulatedTime.truncatingRemainder(dividingBy: 1.0)
                    }
                }
                self.lastUpdateTime = now
            }
        }
    }
    
    func pause() {
        isPlaying = false
        lastUpdateTime = nil
        timer?.invalidate()  // cleanup - don't leak timers
        timer = nil
    }
    
    func seek(to time: Int) {
        currentTime = max(0, time)
        accumulatedTime = 0  // reset fractional time
        lastUpdateTime = isPlaying ? Date() : nil
    }
    
    deinit {
        timer?.invalidate()  // make sure we don't leak
    }
}

