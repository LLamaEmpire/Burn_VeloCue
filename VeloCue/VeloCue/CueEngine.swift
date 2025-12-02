//
//  CueEngine.swift
//  VeloCue
//
//  Created by Sebastian Skora on 2025.
//  Pure timing engine - no UI code, just math and logic.
//

import Foundation

// what the UI needs to know at any given moment
struct CueState {
    let currentSegment: Segment?
    let nextSegment: Segment?
    let currentEvent: SegmentEvent?
    let nextEvent: SegmentEvent?
    let timeElapsed: Int          // seconds into current segment
    let timeRemaining: Int        // seconds left in current segment
    let segmentProgress: Double   // 0.0 to 1.0 for progress bars
    let timeUntilNext: Int?       // seconds until next event or segment
    let totalTrackTime: Int        // total duration of track
}

// pure engine - takes time and config, returns state. no side effects.
struct CueEngine {
    let config: TrackConfig
    
    // main entry point - given a playback time, figure out what should be showing
    func cueState(at playbackTime: Int) -> CueState {
        // find current segment with 1-second overlap to prevent "no active segment" flicker
        let currentSegment = config.segments.first { segment in
            // include segment if we're within 1 second of it starting (smooth transitions)
            playbackTime >= segment.startTime && playbackTime < segment.endTime ||
            (segment.startTime > playbackTime && segment.startTime - playbackTime <= 1)
        }
        
        // find next segment (account for overlap)
        let nextSegment = config.segments.first { segment in
            segment.startTime > playbackTime + 1
        }
        
        // calculate timing for current segment
        let timeElapsed: Int
        let timeRemaining: Int
        let segmentProgress: Double
        
        if let current = currentSegment {
            // if we're showing this segment early, calculate timing as if it hasn't started yet
            let effectivePlaybackTime = max(playbackTime, current.startTime)
            timeElapsed = effectivePlaybackTime - current.startTime
            timeRemaining = current.endTime - effectivePlaybackTime
            let segmentDuration = current.endTime - current.startTime
            segmentProgress = segmentDuration > 0 ? Double(timeElapsed) / Double(segmentDuration) : 0.0
        } else {
            // no current segment - zero everything out
            timeElapsed = 0
            timeRemaining = 0
            segmentProgress = 0.0
        }
        
        // find events within current segment
        let currentEvent: SegmentEvent?
        let nextEvent: SegmentEvent?
        let timeUntilNext: Int?
        
        if let current = currentSegment {
            // use effective time to handle early segment display
            let effectivePlaybackTime = max(playbackTime, current.startTime)
            let segmentTime = effectivePlaybackTime - current.startTime
            currentEvent = current.events.last { event in
                event.offset <= segmentTime
            }
            
            nextEvent = current.events.first { event in
                event.offset > segmentTime
            }
            
            // calculate time until next thing happens
            if let nextEv = nextEvent {
                let eventAbsoluteTime = current.startTime + nextEv.offset
                timeUntilNext = eventAbsoluteTime - playbackTime
            } else if let nextSeg = nextSegment {
                timeUntilNext = nextSeg.startTime - playbackTime
            } else {
                timeUntilNext = nil
            }
        } else {
            // no current segment - look for next segment start
            currentEvent = nil
            nextEvent = nil
            if let nextSeg = nextSegment {
                timeUntilNext = nextSeg.startTime - playbackTime
            } else {
                timeUntilNext = nil
            }
        }
        
        // total track duration for progress bars
        let totalTrackTime = config.segments.last?.endTime ?? 0
        
        return CueState(
            currentSegment: currentSegment,
            nextSegment: nextSegment,
            currentEvent: currentEvent,
            nextEvent: nextEvent,
            timeElapsed: timeElapsed,
            timeRemaining: timeRemaining,
            segmentProgress: segmentProgress,
            timeUntilNext: timeUntilNext,
            totalTrackTime: totalTrackTime
        )
    }
}

// format resistance for display - B for base, B+X for above base
func formatResistance(_ value: Double?) -> String {
    guard let value = value else { return "" }
    if value == 0 {
        return "B"
    } else {
        // clean up decimal display - B+2 instead of B+2.0
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "B+\(Int(value))"
        } else {
            return "B+\(value)"
        }
    }
}

// helpers to get the actual values to use - event overrides segment overrides track
extension Segment {
    func effectiveCue(with event: SegmentEvent?) -> String? {
        event?.cue ?? cue
    }
    
    func effectiveRpmRange(with event: SegmentEvent?) -> String {
        event?.rpmRange ?? rpmRange
    }
    
    func effectivePosition(with event: SegmentEvent?) -> Position {
        event?.position ?? position
    }
    
    func effectiveResistance(with event: SegmentEvent?) -> Double? {
        event?.resistance ?? resistance
    }
    
    func effectivePowerShift(with event: SegmentEvent?) -> PowerShift {
        event?.powerShift ?? powerShift
    }
    
    func effectiveLeaderboard(with event: SegmentEvent?, trackDefault: Bool = true) -> Bool {
        // priority: event -> segment -> track -> default true (On)
        if let eventLeaderboard = event?.leaderboard {
            return eventLeaderboard
        }
        if let segmentLeaderboard = leaderboard {
            return segmentLeaderboard
        }
        return trackDefault
    }
    
    func effectiveLightSettings(with event: SegmentEvent?, trackDefault: String? = nil) -> String? {
        // priority: event -> segment -> track
        if let eventLightSettings = event?.lightSettings {
            return eventLightSettings.isEmpty ? nil : eventLightSettings
        }
        if let segmentLightSettings = lightSettings {
            return segmentLightSettings.isEmpty ? nil : segmentLightSettings
        }
        return trackDefault?.isEmpty == false ? trackDefault : nil
    }
    
    // format the resistance/power shift line - always show all three parts
    func formattedResistanceAndPowerShift(with event: SegmentEvent?) -> String {
        let rpm = effectiveRpmRange(with: event)
        let resistance = effectiveResistance(with: event)
        let powerShift = effectivePowerShift(with: event)
        
        // always show all three: RPM / Resistance / PowerShift
        let resistanceStr = resistance.map { formatResistance($0) } ?? "B"
        return "\(rpm) / \(resistanceStr) / \(powerShift.rawValue)"
    }
    
    // figure out what actually changed in an event (for green highlighting)
    func changesInEvent(_ event: SegmentEvent?) -> EventChanges {
        guard let event = event else {
            return EventChanges()
        }
        
        var changes = EventChanges()
        
        if let cue = event.cue {
            changes.cue = cue
        }
        if let rpmRange = event.rpmRange, rpmRange != self.rpmRange {
            changes.rpmRange = rpmRange
        }
        if let position = event.position, position != self.position {
            changes.position = position
        }
        if let resistance = event.resistance, resistance != (self.resistance ?? 0.0) {
            changes.resistance = resistance
        }
        if let powerShift = event.powerShift, powerShift != self.powerShift {
            changes.powerShift = powerShift
        }
        if let leaderboard = event.leaderboard, leaderboard != (self.leaderboard ?? true) {
            changes.leaderboard = leaderboard
        }
        if let lightSettings = event.lightSettings, lightSettings != (self.lightSettings ?? "") {
            changes.lightSettings = lightSettings
        }
        
        return changes
    }
}

// tracks what changed in an event - used for green highlighting
struct EventChanges {
    var cue: String?
    var rpmRange: String?
    var position: Position?
    var resistance: Double?
    var powerShift: PowerShift?
    var leaderboard: Bool?
    var lightSettings: String?
    
    // quick check if anything actually changed
    var hasAny: Bool {
        cue != nil || rpmRange != nil || position != nil || resistance != nil || powerShift != nil || leaderboard != nil || lightSettings != nil
    }
}

