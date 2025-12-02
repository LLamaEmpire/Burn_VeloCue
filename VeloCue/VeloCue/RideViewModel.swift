//
//  RideViewModel.swift
//  VeloCue
//
//  Created by Sebastian Skora on 2025.
//  State management and UI logic - keeps the view dumb.
//

import Foundation
import SwiftUI
import Observation

// main viewmodel - handles all the state that the view needs
@MainActor
@Observable
class RideViewModel {
    let config: TrackConfig
    let timeSource: PlaybackTimeSource
    let store: TrackConfigStore?
    private let cueEngine: CueEngine
    
    private(set) var cueState: CueState
    nonisolated(unsafe) private var observationTask: Task<Void, Never>?
    
    // store previous segment values for green highlighting change detection
    // these persist across view recreations so we don't lose the animation
    var _previousSegmentId: UUID?
    var _previousPosition: Position?
    var _previousRpm: String?
    var _previousResistance: Double?
    var _previousPowerShift: PowerShift?
    var _previousLeaderboard: Bool?
    var _previousLightSettings: String?
    
    // which fields changed in the current transition (for green highlighting)
    var _changedFields: Set<String>?
    
    // helps us survive the gap between segments without losing our mind
    var _lastValidSegmentId: UUID?
    
    // track if we've seen at least one segment (first segment is special)
    var _hasSeenFirstSegment: Bool = false
    
    // green pulsing animation state - persists across view recreations
    var _pulseScale: CGFloat = 1.0
    var _shouldPulse: Bool = false
    var _pulseTimerTask: Task<Void, Never>?
    
    // current cue font size (can be changed during ride)
    var _currentCueFontSize: CueFontSize
    
    // cue pulsing animation state (gentle pulse on text)
    var _cuePulseScale: CGFloat = 1.0
    var _cuePulseOpacity: Double = 1.0
    var _cueShouldPulse: Bool = false
    
    init(config: TrackConfig, timeSource: PlaybackTimeSource, store: TrackConfigStore? = nil) {
        self.config = config
        self.timeSource = timeSource
        self.store = store
        self.cueEngine = CueEngine(config: config)
        self.cueState = cueEngine.cueState(at: 0)
        self._currentCueFontSize = config.cueFontSize
        
        startObserving()
    }
    
    // get the next track for preview (if linked)
    var linkedTrack: TrackConfig? {
        guard let nextId = config.nextTrackConfigId,
              let store = store else {
            return nil
        }
        return store.configs.first { $0.id == nextId }
    }
    
    // start the time observation loop - polls every 100ms
    private func startObserving() {
        observationTask?.cancel()
        
        // poll periodically for updates - 100ms is smooth enough
        observationTask = Task { @MainActor in
            while !Task.isCancelled {
                updateCueState()
                try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
            }
        }
    }
    
    // update the current cue state based on playback time
    private func updateCueState() {
        cueState = cueEngine.cueState(at: timeSource.currentTime)
    }
    
    // MARK: - Playback Controls
    
    var isPlaying: Bool {
        timeSource.isPlaying
    }
    
    var currentTime: Int {
        timeSource.currentTime
    }
    
    func play() {
        timeSource.play()
    }
    
    func pause() {
        timeSource.pause()
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func seek(to time: Int) {
        timeSource.seek(to: time)
        updateCueState() // update immediately so UI doesn't lag
    }
    
    // MARK: - Navigation Helpers
    
    func jumpToNextSegment() {
        guard let next = cueState.nextSegment else { return }
        seek(to: next.startTime)
    }
    
    func jumpToPreviousSegment() {
        guard let current = cueState.currentSegment else {
            // if no current segment, jump to first
            if let first = config.segments.first {
                seek(to: first.startTime)
            }
            return
        }
        
        // find previous segment
        if let previous = config.segments.last(where: { $0.endTime <= current.startTime }) {
            seek(to: previous.startTime)
        } else {
            seek(to: 0)
        }
    }
    
    func stepForward(seconds: Int = 5) {
        seek(to: timeSource.currentTime + seconds)
    }
    
    func stepBackward(seconds: Int = 5) {
        seek(to: max(0, timeSource.currentTime - seconds))
    }
    
    deinit {
        observationTask?.cancel() // cleanup - don't leak tasks
    }
}

