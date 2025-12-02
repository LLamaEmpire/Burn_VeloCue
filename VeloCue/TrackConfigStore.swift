//
//  TrackConfigStore.swift
//  VeloCue
//
//  Created by Sebastian Skora on 2025.
//  Handles saving/loading workout data to local storage.
//

import Foundation
import SwiftUI
import Observation

// manages all workout data - saves to device storage
@MainActor
@Observable
class TrackConfigStore {
    // workouts contain tracks - this is the main data structure
    var workouts: [Workout] = []
    
    // backward compatibility - old code still expects configs array
    var configs: [TrackConfig] {
        workouts.flatMap { $0.tracks }
    }

    // MARK: - Init

    init() {
        load()
    }

    // MARK: - Persistence

    // where we store the JSON file on device
    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("workouts.json")
    }

    // load workouts from disk or create defaults
    func load() {
        do {
            let url = fileURL
            guard FileManager.default.fileExists(atPath: url.path) else {
                // first run - create default workout so app isn't empty
                if workouts.isEmpty {
                    let defaultWorkout = Workout(name: "My Workout")
                    workouts = [defaultWorkout]
                    save()
                }
                return
            }

            let data = try Data(contentsOf: url)
            workouts = try JSONDecoder().decode([Workout].self, from: data)
            
            // make sure we always have at least one workout
            if workouts.isEmpty {
                let defaultWorkout = Workout(name: "My Workout")
                workouts = [defaultWorkout]
                save()
            }
        } catch {
            print("Failed to load workouts: \(error)")
            // Try to migrate from old format
            migrateFromOldFormat()
        }
    }
    
    private func migrateFromOldFormat() {
        let oldURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("track_configs.json")
        
        guard FileManager.default.fileExists(atPath: oldURL.path) else {
            // No old file, create default workout
            let defaultWorkout = Workout(name: "My Workout")
            workouts = [defaultWorkout]
            save()
            return
        }
        
        do {
            let data = try Data(contentsOf: oldURL)
            // Try to decode as old format (without workoutId)
            struct OldTrackConfig: Codable {
                let id: UUID
                var name: String
                var spotifyURI: String
                var segments: [Segment]
                var nextTrackConfigId: UUID?
            }
            
            let oldConfigs = try JSONDecoder().decode([OldTrackConfig].self, from: data)
            
            // Create a default workout and migrate tracks
            let defaultWorkoutId = UUID()
            let migratedTracks = oldConfigs.map { oldConfig in
                TrackConfig(
                    id: oldConfig.id,
                    name: oldConfig.name,
                    spotifyURI: oldConfig.spotifyURI,
                    segments: oldConfig.segments,
                    nextTrackConfigId: oldConfig.nextTrackConfigId,
                    workoutId: defaultWorkoutId
                )
            }
            
            let defaultWorkout = Workout(
                id: defaultWorkoutId,
                name: "My Workout",
                tracks: migratedTracks
            )
            
            workouts = [defaultWorkout]
            save()
        } catch {
            print("Failed to migrate: \(error)")
            // Create default workout
            let defaultWorkout = Workout(name: "My Workout")
            workouts = [defaultWorkout]
            save()
        }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(workouts)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("Failed to save workouts: \(error)")
        }
    }

    // MARK: - Workout Management

    func addWorkout(_ workout: Workout) {
        workouts.append(workout)
        workouts.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        save()
    }
    
    func updateWorkout(_ workout: Workout) {
        if let index = workouts.firstIndex(where: { $0.id == workout.id }) {
            workouts[index] = workout
            workouts.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            save()
        }
    }
    
    func deleteWorkout(_ workout: Workout) {
        workouts.removeAll { $0.id == workout.id }
        save()
    }
    
    // MARK: - Track Management

    func add(_ config: TrackConfig, to workoutId: UUID) -> TrackConfig? {
        guard let workoutIndex = workouts.firstIndex(where: { $0.id == workoutId }) else {
            return nil
        }
        
        // Check if track with same URI already exists in this workout
        if let existingTrack = workouts[workoutIndex].tracks.first(where: { $0.spotifyURI == config.spotifyURI }) {
            return existingTrack // Return existing track instead of adding duplicate
        }
        
        workouts[workoutIndex].tracks.append(config)
        workouts[workoutIndex].tracks.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        save()
        return config
    }

    func update(_ config: TrackConfig) {
        // Find the workout containing this track
        for workoutIndex in workouts.indices {
            if let trackIndex = workouts[workoutIndex].tracks.firstIndex(where: { $0.id == config.id }) {
                workouts[workoutIndex].tracks[trackIndex] = config
                workouts[workoutIndex].tracks.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                save()
                return
            }
        }
    }

    func deleteTrack(_ config: TrackConfig) {
        for workoutIndex in workouts.indices {
            workouts[workoutIndex].tracks.removeAll { $0.id == config.id }
        }
        save()
    }
    
    func getWorkout(for trackId: UUID) -> Workout? {
        return workouts.first { workout in
            workout.tracks.contains { $0.id == trackId }
        }
    }
    
    // MARK: - Backward Compatibility
    
    func add(_ config: TrackConfig) {
        // For backward compatibility, add to first workout
        if let firstWorkout = workouts.first {
            _ = add(config, to: firstWorkout.id)
        }
    }
    
    func delete(at offsets: IndexSet) {
        // For backward compatibility - this is less useful now
        // Should use deleteTrack instead
        let allTracks = configs
        let tracksToDelete = offsets.map { allTracks[$0] }
        for track in tracksToDelete {
            deleteTrack(track)
        }
    }
    
    // MARK: - Export/Import
    
    func exportWorkouts() -> Data? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(workouts)
        } catch {
            print("Failed to export workouts: \(error)")
            return nil
        }
    }
    
    func importWorkouts(from data: Data) {
        do {
            let decoder = JSONDecoder()
            let importedWorkouts = try decoder.decode([Workout].self, from: data)
            
            // Merge imported workouts with existing ones
            // If a workout with the same name exists, replace it; otherwise add it
            for importedWorkout in importedWorkouts {
                if let existingIndex = workouts.firstIndex(where: { $0.name == importedWorkout.name }) {
                    // Replace existing workout with same name
                    workouts[existingIndex] = importedWorkout
                } else {
                    // Add new workout
                    workouts.append(importedWorkout)
                }
            }
            
            workouts.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            save()
        } catch {
            print("Failed to import workouts: \(error)")
        }
    }
    
    // MARK: - Track-Level Export/Import
    
    func exportTrack(_ track: TrackConfig) -> Data? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(track)
        } catch {
            print("Failed to export track: \(error)")
            return nil
        }
    }
    
    func importTrack(from data: Data, preservingWorkoutId workoutId: UUID) -> TrackConfig? {
        do {
            let decoder = JSONDecoder()
            
            // First, try to decode as-is
            var importedTrack: TrackConfig
            do {
                importedTrack = try decoder.decode(TrackConfig.self, from: data)
            } catch {
                // If decoding fails due to invalid UUIDs, try to fix them
                print("Initial decode failed, attempting to fix invalid UUIDs: \(error)")
                importedTrack = try decodeTrackWithUUIDFix(from: data)
            }
            
            // Preserve the workoutId (don't change which workout it belongs to)
            importedTrack.workoutId = workoutId
            
            // Update the track in the store
            update(importedTrack)
            
            return importedTrack
        } catch {
            print("Failed to import track: \(error)")
            return nil
        }
    }
    
    /// Decode track and fix invalid UUIDs by regenerating them
    private func decodeTrackWithUUIDFix(from data: Data) throws -> TrackConfig {
        // Decode as a dictionary first
        guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "TrackImport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON structure"])
        }
        
        // Helper to validate and fix UUID
        func fixUUID(_ idString: String?) -> String {
            guard let idString = idString else {
                print("TrackConfigStore: UUID is nil, generating new UUID")
                return UUID().uuidString
            }
            if let uuid = UUID(uuidString: idString) {
                return uuid.uuidString
            } else {
                print("TrackConfigStore: Invalid UUID '\(idString)', generating new UUID")
                return UUID().uuidString
            }
        }
        
        // Fix track ID if invalid
        if let oldId = json["id"] as? String {
            let newId = fixUUID(oldId)
            if oldId != newId {
                print("TrackConfigStore: Fixed track ID: '\(oldId)' -> '\(newId)'")
            }
            json["id"] = newId
        } else {
            json["id"] = UUID().uuidString
        }
        
        // Fix nextTrackConfigId if present and invalid
        if let nextId = json["nextTrackConfigId"] as? String {
            let fixedId = fixUUID(nextId)
            if nextId != fixedId {
                print("TrackConfigStore: Fixed nextTrackConfigId: '\(nextId)' -> '\(fixedId)'")
            }
            json["nextTrackConfigId"] = fixedId
        }
        
        // Fix segments
        if let segmentsArray = json["segments"] as? [[String: Any]] {
            var fixedSegments: [[String: Any]] = []
            for segmentDict in segmentsArray {
                var fixedSegment = segmentDict
                
                // Fix segment ID
                if let oldId = fixedSegment["id"] as? String {
                    let newId = fixUUID(oldId)
                    if oldId != newId {
                        print("TrackConfigStore: Fixed segment ID: '\(oldId)' -> '\(newId)'")
                    }
                    fixedSegment["id"] = newId
                } else {
                    fixedSegment["id"] = UUID().uuidString
                }
                
                // Fix events
                if let eventsArray = fixedSegment["events"] as? [[String: Any]] {
                    var fixedEvents: [[String: Any]] = []
                    for eventDict in eventsArray {
                        var fixedEvent = eventDict
                        if let oldId = fixedEvent["id"] as? String {
                            let newId = fixUUID(oldId)
                            if oldId != newId {
                                print("TrackConfigStore: Fixed event ID: '\(oldId)' -> '\(newId)'")
                            }
                            fixedEvent["id"] = newId
                        } else {
                            fixedEvent["id"] = UUID().uuidString
                        }
                        fixedEvents.append(fixedEvent)
                    }
                    fixedSegment["events"] = fixedEvents
                }
                
                fixedSegments.append(fixedSegment)
            }
            json["segments"] = fixedSegments
        }
        
        // Now decode the fixed JSON
        let fixedData = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        return try decoder.decode(TrackConfig.self, from: fixedData)
    }
}
