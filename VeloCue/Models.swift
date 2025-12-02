//
//  Models.swift
//  VeloCue
//
//  Created by Sebastian Skora on 2025.
//  Core data models for the spin class app.
//

import Foundation

// ride positions - these map directly to what instructors say in class
enum Position: String, Codable, Hashable, CaseIterable {
    case standing = "Standing"
    case seated = "Seated"
    case either = "Either"
}

// which side to bias power toward - left/middle/right for the balance shifts
enum PowerShift: String, Codable, Hashable, CaseIterable {
    case left = "LEFT"
    case middle = "MIDDLE"
    case right = "RIGHT"
}

// font sizes for cue text - maps to swiftui font sizes
enum CueFontSize: String, Codable, Hashable, CaseIterable {
    case small = "small"   // title2
    case normal = "normal" // title - default
    case large = "large"   // largeTitle
}

// track types for organizing workouts - affects HR zones and sort order
enum TrackType: String, Codable, Hashable, CaseIterable {
    case warmup = "Warmup"
    case interval = "Interval"
    case firstClimb = "First Climb"
    case hiit = "HIIT"
    case isolation = "Isolation"
    case meTime = "MeTime"
    case speed = "Speed"
    case finalClimb = "Final Climb"
    case cooldown = "Cooldown"
    
    // HR zones for each track type - some tracks don't have HR targets
    var heartRateRange: String? {
        switch self {
        case .warmup:
            return "HR 30-60"
        case .interval:
            return "HR 60-80"
        case .firstClimb:
            return "HR 70-95"
        case .hiit:
            return "HR 70-95"
        case .isolation:
            return "HR 50-70"
        case .meTime:
            return nil // no HR target for me time tracks
        case .speed:
            return "HR 50-70"
        case .finalClimb:
            return "HR 75-95"
        case .cooldown:
            return nil // no HR target for cooldown
        }
    }
}

// events that happen within a segment - think "add resistance at 30s"
struct SegmentEvent: Identifiable, Codable, Hashable {
    let id: UUID
    var offset: Int          // seconds from segment start when this triggers
    var cue: String?         // optional cue text override
    var rpmRange: String?   // optional RPM range override
    var position: Position?  // optional position override
    var resistance: Double?     // optional resistance override (0 = base, >0 = B+X, can be decimal like 2.5)
    var powerShift: PowerShift? // optional power shift override
    var leaderboard: Bool?      // optional leaderboard override (nil = use parent, true = On, false = Off)
    var lightSettings: String?  // optional light settings text override
    var cueFontSize: CueFontSize? // optional cue font size override
    var cuePulsing: Bool? // optional cue pulsing override (nil = use parent, true = On, false = Off)

    init(
        id: UUID = UUID(),
        offset: Int,
        cue: String? = nil,
        rpmRange: String? = nil,
        position: Position? = nil,
        resistance: Double? = nil,
        powerShift: PowerShift? = nil,
        leaderboard: Bool? = nil,
        lightSettings: String? = nil,
        cueFontSize: CueFontSize? = nil,
        cuePulsing: Bool? = nil
    ) {
        self.id = id
        self.offset = offset
        self.cue = cue
        self.rpmRange = rpmRange
        self.position = position
        self.resistance = resistance
        self.powerShift = powerShift
        self.leaderboard = leaderboard
        self.lightSettings = lightSettings
        self.cueFontSize = cueFontSize
        self.cuePulsing = cuePulsing
    }
}

// a chunk of time within a track with specific instructions
struct Segment: Identifiable, Codable, Hashable {
    let id: UUID
    var startTime: Int        // seconds from track start
    var endTime: Int          // seconds from track start
    var label: String         // "Standing sprint" - what we show on screen
    var rpmRange: String      // "100–110 RPM" - target cadence
    var position: Position    // Standing / Seated / Either
    var resistance: Double?      // optional initial resistance (0 = base, >0 = B+X, can be decimal like 2.5)
    var powerShift: PowerShift // initial power shift (default: LEFT)
    var cue: String?          // optional cue text
    var leaderboard: Bool?    // optional leaderboard (nil = use track default, true = On, false = Off)
    var lightSettings: String? // optional light settings text
    var cueFontSize: CueFontSize? // optional cue font size override
    var cuePulsing: Bool? // optional cue pulsing override (nil = use parent, true = On, false = Off)
    var events: [SegmentEvent] // things that happen during this segment

    init(
        id: UUID = UUID(),
        startTime: Int,
        endTime: Int,
        label: String,
        rpmRange: String,
        position: Position = .either,
        resistance: Double? = nil,
        powerShift: PowerShift = .left,
        cue: String? = nil,
        leaderboard: Bool? = nil,
        lightSettings: String? = nil,
        cueFontSize: CueFontSize? = nil,
        cuePulsing: Bool? = nil,
        events: [SegmentEvent] = []
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.label = label
        self.rpmRange = rpmRange
        self.position = position
        self.resistance = resistance
        self.powerShift = powerShift
        self.cue = cue
        self.leaderboard = leaderboard
        self.lightSettings = lightSettings
        self.cueFontSize = cueFontSize
        self.cuePulsing = cuePulsing
        // sort events so they trigger in the right order
        self.events = events.sorted { $0.offset < $1.offset }
    }
    
    // MARK: - Effective Value Methods
    
    // get the actual font size to use - event overrides segment overrides track
    func effectiveCueFontSize(with event: SegmentEvent?, trackDefault: CueFontSize) -> CueFontSize {
        return event?.cueFontSize ?? self.cueFontSize ?? trackDefault
    }
    
    // get the actual pulsing setting - event overrides segment overrides track
    func effectiveCuePulsing(with event: SegmentEvent?, trackDefault: Bool) -> Bool {
        return event?.cuePulsing ?? self.cuePulsing ?? trackDefault
    }
}

// helper for events to get their font size - falls back to track default
extension SegmentEvent {
    func effectiveCueFontSize(trackDefault: CueFontSize) -> CueFontSize {
        return self.cueFontSize ?? trackDefault
    }
}

// a single song/track in a workout
struct TrackConfig: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String          // e.g. "Losing It (spin edit)"
    var spotifyURI: String    // "spotify:track:…" - needed for spotify integration
    var segments: [Segment]   // sorted by startTime
    var nextTrackConfigId: UUID?  // Optional link to next track for preview
    var workoutId: UUID       // Required: belongs to a workout
    var trackType: TrackType? // Optional track type (Warmup, Interval, etc.)
    var leaderboard: Bool     // leaderboard setting (default: true = On)
    var lightSettings: String? // optional light settings text
    var cueFontSize: CueFontSize // default cue font size for the track
    var cuePulsing: Bool // default cue pulsing for the track

    init(
        id: UUID = UUID(),
        name: String,
        spotifyURI: String,
        segments: [Segment] = [],
        nextTrackConfigId: UUID? = nil,
        workoutId: UUID,
        trackType: TrackType? = nil,
        leaderboard: Bool = true,
        lightSettings: String? = nil,
        cueFontSize: CueFontSize = .normal,
        cuePulsing: Bool = false
    ) {
        self.id = id
        self.name = name
        self.spotifyURI = spotifyURI
        // sort segments so they play in order
        self.segments = segments.sorted { $0.startTime < $1.startTime }
        self.nextTrackConfigId = nextTrackConfigId
        self.workoutId = workoutId
        self.trackType = trackType
        self.leaderboard = leaderboard
        self.lightSettings = lightSettings
        self.cueFontSize = cueFontSize
        self.cuePulsing = cuePulsing
    }
}

// top-level container - a full spin class workout
struct Workout: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String          // e.g. "Morning Spin Class"
    var tracks: [TrackConfig] // all tracks in this workout
    
    init(
        id: UUID = UUID(),
        name: String,
        tracks: [TrackConfig] = []
    ) {
        self.id = id
        self.name = name
        self.tracks = tracks
    }
}