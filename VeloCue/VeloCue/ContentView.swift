//
//  ContentView.swift
//  VeloCue
//
//  Created by Sebastian Skora on 2025.
//  Main app screen - workout list and track management.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

// main app view - shows workouts, tracks, and handles all the management bullshit
struct ContentView: View {
    @Environment(TrackConfigStore.self) private var configStore
    @Environment(SpotifyService.self) private var spotifyService
    @State private var selectedRideConfig: TrackConfig?  // currently selected track
    @State private var showSpotifyError: Bool = false    // spotify connection errors
    @State private var spotifyErrorMessage: String = ""
    @State private var isCreatingFromSpotify: Bool = false  // creating track from Spotify
    @State private var showWorkoutPicker: Bool = false   // pick which workout to show
    @State private var showNewWorkoutAlert: Bool = false // create new workout dialog
    @State private var newWorkoutName: String = ""       // name for new workout
    @State private var pendingTrackAction: (() -> Void)? // action to do after workout picker
    @State private var selectedWorkout: Workout?         // currently selected workout
    @State private var navigateToTrack: TrackConfig?     // for navigation to ride view
    @State private var currentWorkout: Workout?          // the workout we're displaying
    @State private var showDeleteConfirmation: Bool = false  // delete workout confirmation
    @State private var workoutToDelete: Workout?         // which workout to delete
    @State private var deleteConfirmationText: String = ""  // text user must type to confirm
    @State private var showImportPicker: Bool = false    // file import picker
    @State private var showImportClipboardAlert: Bool = false  // clipboard import dialog
    @State private var importClipboardText: String = ""  // clipboard JSON content
    
    // sort tracks by type then by nextTrack links - this is surprisingly complex
private var displayedTracks: [TrackConfig] {
    guard let workout = currentWorkout else { return [] }
    
    // first group tracks by TrackType so we can sort them in the right order
    let tracksByType = Dictionary(grouping: workout.tracks) { trackTypeSortOrder($0.trackType) }
    
    // build a map of all tracks for link resolution - need this for nextTrack sorting
    let allTracksMap = Dictionary(uniqueKeysWithValues: workout.tracks.map { ($0.id, $0) })
    
    // sort each group by next track links, then combine everything
    var sortedTracks: [TrackConfig] = []
    
    // process each TrackType group in order (1-9 are the real types)
    for typeOrder in 1...9 {
        guard let tracks = tracksByType[typeOrder] else { continue }
        
        // sort tracks within this type by following nextTrack links
        let sortedGroup = sortTracksByNextLink(tracks, allTracks: allTracksMap)
        sortedTracks.append(contentsOf: sortedGroup)
    }
    
    // add tracks without a type at the end (999 is our "no type" marker)
    if let untypedTracks = tracksByType[999] {
        let sortedGroup = sortTracksByNextLink(untypedTracks, allTracks: allTracksMap)
        sortedTracks.append(contentsOf: sortedGroup)
    }
    
    return sortedTracks
}
    
    /// Sort tracks by following next track links
    /// Tracks that are linked to appear first, following the chain
    /// Tracks not in any chain are sorted by name at the end
    /// IMPORTANT: Only follows links within the same TrackType group
    private func sortTracksByNextLink(_ tracks: [TrackConfig], allTracks: [UUID: TrackConfig]) -> [TrackConfig] {
        guard !tracks.isEmpty else { return [] }
        
        // Build a map of track ID to track (only tracks in this group)
        let trackMap = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        let trackIdsInGroup = Set(tracks.map { $0.id })
        
        // Find tracks that are pointed to by other tracks' nextTrackConfigId
        // Check ALL tracks (not just this group) to see which ones in this group are linked to
        let linkedTrackIds = Set(allTracks.values.compactMap { track in
            // If this track's nextTrackConfigId points to a track in our current group, mark that target
            if let nextId = track.nextTrackConfigId,
               trackIdsInGroup.contains(nextId) {
                return nextId
            }
            return nil
        })
        
        // Find head tracks (tracks that aren't pointed to by any other track)
        let headTracks = tracks.filter { !linkedTrackIds.contains($0.id) }
        
        // Follow chains from each head track (only within this group)
        var sorted: [TrackConfig] = []
        var processed = Set<UUID>()
        
        // Process head tracks first
        for headTrack in headTracks {
            var currentTrack: TrackConfig? = headTrack
            while let track = currentTrack, !processed.contains(track.id) {
                sorted.append(track)
                processed.insert(track.id)
                // Follow the next link ONLY if it's in this same group
                if let nextId = track.nextTrackConfigId,
                   trackIdsInGroup.contains(nextId),
                   let nextTrack = trackMap[nextId] {
                    currentTrack = nextTrack
                } else {
                    currentTrack = nil
                }
            }
        }
        
        // Add remaining tracks (not in any chain) sorted by name
        let remainingTracks = tracks.filter { !processed.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        sorted.append(contentsOf: remainingTracks)
        
        return sorted
    }
    
    /// Returns sort order for TrackType (lower number = earlier in list)
    /// Tracks without a type go to the end (order 999)
    private func trackTypeSortOrder(_ trackType: TrackType?) -> Int {
        guard let trackType = trackType else { return 999 }
        
        switch trackType {
        case .warmup: return 1
        case .interval: return 2
        case .firstClimb: return 3
        case .hiit: return 4
        case .isolation: return 5
        case .meTime: return 6
        case .speed: return 7
        case .finalClimb: return 8
        case .cooldown: return 9
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Rider Mode button at the top
                Section {
                    NavigationLink(value: "rider-mode") {
                        HStack {
                            Image(systemName: "figure.run")
                                .font(.title2)
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Rider Mode")
                                    .font(.headline)
                                Text("Auto-match to currently playing Spotify track")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                // Tracks for selected workout
                Section {
                    ForEach(displayedTracks) { config in
                        HStack {
                            NavigationLink(value: config.id) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(config.name)
                                        .font(.headline)
                                    Text(config.spotifyURI)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button {
                                selectedRideConfig = config
                            } label: {
                                Image(systemName: "play.circle.fill")
                                    .foregroundStyle(.blue)
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .onDelete { offsets in
                        deleteTracks(at: offsets)
                    }
                }
                
                // Export/Import and Delete buttons at the bottom
                Section {
                    HStack(spacing: 12) {
                        // Export button
                        Button {
                            exportWorkouts()
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        // Import button
                        Menu {
                            Button {
                                showImportPicker = true
                            } label: {
                                Label("Import from File", systemImage: "doc")
                            }
                            Button {
                                // Try to get JSON from clipboard
                                if let clipboardString = UIPasteboard.general.string,
                                   let data = clipboardString.data(using: .utf8) {
                                    importWorkouts(from: data)
                                } else {
                                    showImportClipboardAlert = true
                                }
                            } label: {
                                Label("Import from Clipboard", systemImage: "doc.on.clipboard")
                            }
                        } label: {
                            Label("Import", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        // Delete Workout button (only if more than one workout)
                        if let workout = currentWorkout, configStore.workouts.count > 1 {
                            Button(role: .destructive) {
                                workoutToDelete = workout
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .navigationTitle("VeloCue")
            .navigationDestination(for: UUID.self) { id in
                if let config = configStore.configs.first(where: { $0.id == id }) {
                    TrackConfigEditorView(config: config)
                }
            }
            .navigationDestination(item: $navigateToTrack) { track in
                TrackConfigEditorView(config: track)
            }
            .navigationDestination(for: String.self) { value in
                if value == "rider-mode" {
                    RiderModeView()
                }
            }
            .navigationDestination(item: $selectedRideConfig) { config in
                RideModeSelectionView(
                    config: config,
                    store: configStore
                )
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        ForEach(configStore.workouts) { workout in
                            Button {
                                currentWorkout = workout
                            } label: {
                                Label(workout.name, systemImage: currentWorkout?.id == workout.id ? "checkmark" : "")
                            }
                        }
                        
                        Divider()
                        
                        Button {
                            showNewWorkoutAlert = true
                        } label: {
                            Label("New Workout", systemImage: "plus")
                        }
                    } label: {
                        HStack {
                            Text(currentWorkout?.name ?? "Select Workout")
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: addNewConfig) {
                            Image(systemName: "plus")
                        }
                        .disabled(currentWorkout == nil)
                        
                        Button(action: createFromSpotify) {
                            Image(systemName: "music.note")
                        }
                        .disabled(isCreatingFromSpotify || currentWorkout == nil)
                    }
                }
            }
            .onAppear {
                // Set initial workout if none selected
                if currentWorkout == nil {
                    currentWorkout = configStore.workouts.first
                }
            }
            .onChange(of: configStore.workouts) { oldValue, newValue in
                // Update current workout if it was deleted
                if let current = currentWorkout, !newValue.contains(where: { $0.id == current.id }) {
                    currentWorkout = newValue.first
                } else if currentWorkout == nil && !newValue.isEmpty {
                    currentWorkout = newValue.first
                }
            }
            .alert("Spotify Error", isPresented: $showSpotifyError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(spotifyErrorMessage)
            }
            .sheet(isPresented: $showWorkoutPicker) {
                WorkoutPickerView(
                    workouts: configStore.workouts,
                    onSelect: { workout in
                        currentWorkout = workout
                        showWorkoutPicker = false
                        if let action = pendingTrackAction {
                            action()
                        }
                    },
                    onCreateNew: {
                        showWorkoutPicker = false
                        showNewWorkoutAlert = true
                    }
                )
            }
            .alert("New Workout", isPresented: $showNewWorkoutAlert) {
                TextField("Workout Name", text: $newWorkoutName)
                Button("Cancel", role: .cancel) {
                    newWorkoutName = ""
                }
                Button("Create") {
                    createNewWorkout()
                }
                .disabled(newWorkoutName.trimmingCharacters(in: .whitespaces).isEmpty)
            } message: {
                Text("Enter a name for the new workout")
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [UTType.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        importWorkoutsFromFile(url: url)
                    }
                case .failure(let error):
                    print("Import failed: \(error.localizedDescription)")
                }
            }
            .alert("Import from Clipboard", isPresented: $showImportClipboardAlert) {
                TextField("Paste JSON here", text: $importClipboardText, axis: .vertical)
                    .lineLimit(5...20)
                Button("Import") {
                    if let data = importClipboardText.data(using: .utf8) {
                        importWorkouts(from: data)
                        importClipboardText = ""
                    }
                }
                Button("Cancel", role: .cancel) {
                    importClipboardText = ""
                }
            } message: {
                Text("Paste the exported JSON data here")
            }
            .alert("Delete Workout", isPresented: $showDeleteConfirmation) {
                TextField("Type 'yes' to confirm", text: $deleteConfirmationText)
                Button("Cancel", role: .cancel) {
                    deleteConfirmationText = ""
                    workoutToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    deleteWorkout()
                }
                .disabled(deleteConfirmationText.lowercased() != "yes")
            } message: {
                if let workout = workoutToDelete {
                    Text("This will permanently delete '\(workout.name)' and all its tracks. Type 'yes' to confirm.")
                } else {
                    Text("This will permanently delete the workout and all its tracks. Type 'yes' to confirm.")
                }
            }
        }
    }

    private func deleteTracks(at offsets: IndexSet) {
        guard let workout = currentWorkout else { return }
        let tracksToDelete = offsets.map { displayedTracks[$0] }
        for track in tracksToDelete {
            configStore.deleteTrack(track)
        }
        // Refresh current workout after deletion
        if let updatedWorkout = configStore.workouts.first(where: { $0.id == workout.id }) {
            currentWorkout = updatedWorkout
        }
    }

    private func addNewConfig() {
        guard let workout = currentWorkout else { return }
        
        let newConfig = TrackConfig(
            name: "New Track",
            spotifyURI: "spotify:track:placeholder",
            workoutId: workout.id
        )
        
        if let existing = configStore.add(newConfig, to: workout.id) {
            // Navigate to the track (whether new or existing)
            navigateToTrack = existing
        }
        // Update current workout to refresh the list
        if let updatedWorkout = configStore.workouts.first(where: { $0.id == workout.id }) {
            currentWorkout = updatedWorkout
        }
    }
    
    private func createFromSpotify() {
        guard let workout = currentWorkout else { return }
        
        isCreatingFromSpotify = true
        
        Task {
            do {
                // Connect to Spotify if not already connected
                if !spotifyService.isConnected {
                    try await spotifyService.connect()
                }
                
                // Fetch current track
                let track = try await spotifyService.fetchCurrentTrack()
                
                // Check if track already exists in this workout
                if let existingTrack = workout.tracks.first(where: { $0.spotifyURI == track.uri }) {
                    // Track exists - navigate to it
                    await MainActor.run {
                        isCreatingFromSpotify = false
                        navigateToTrack = existingTrack
                    }
                } else {
                    // Create new TrackConfig
                    let newConfig = TrackConfig(
                        name: track.name,
                        spotifyURI: track.uri,
                        workoutId: workout.id
                    )
                    
                    await MainActor.run {
                        if let added = configStore.add(newConfig, to: workout.id) {
                            navigateToTrack = added
                        }
                        isCreatingFromSpotify = false
                        // Update current workout to refresh the list
                        if let updatedWorkout = configStore.workouts.first(where: { $0.id == workout.id }) {
                            currentWorkout = updatedWorkout
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isCreatingFromSpotify = false
                    spotifyErrorMessage = error.localizedDescription
                    showSpotifyError = true
                }
            }
        }
    }
    
    private func getSelectedWorkout() -> Workout? {
        // For now, use first workout or create default
        if configStore.workouts.isEmpty {
            let defaultWorkout = Workout(name: "My Workout")
            configStore.addWorkout(defaultWorkout)
            return defaultWorkout
        }
        return configStore.workouts.first
    }
    
    private func createNewWorkout() {
        let workoutName = newWorkoutName.trimmingCharacters(in: .whitespaces)
        guard !workoutName.isEmpty else { return }
        
        let newWorkout = Workout(name: workoutName)
        configStore.addWorkout(newWorkout)
        currentWorkout = newWorkout
        newWorkoutName = ""
        
        // Execute pending action if any
        if let action = pendingTrackAction {
            pendingTrackAction = nil
            action()
        }
    }
    
    private func deleteWorkout() {
        guard let workout = workoutToDelete else { return }
        
        // Prevent deleting the last workout
        guard configStore.workouts.count > 1 else {
            deleteConfirmationText = ""
            workoutToDelete = nil
            return
        }
        
        // Delete the workout
        configStore.deleteWorkout(workout)
        
        // Clear the current workout if it was the one deleted
        if currentWorkout?.id == workout.id {
            currentWorkout = configStore.workouts.first
        }
        
        // Reset confirmation state
        deleteConfirmationText = ""
        workoutToDelete = nil
    }
    
    private func exportWorkouts() {
        // Get the workouts JSON data
        guard let jsonData = configStore.exportWorkouts(),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("Failed to export workouts")
            return
        }
        
        // Copy to clipboard
        UIPasteboard.general.string = jsonString
        
        // Show a brief confirmation (you could add a toast/alert here if desired)
        print("Workouts exported to clipboard")
    }
    
    private func importWorkoutsFromFile(url: URL) {
        do {
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access file")
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            let data = try Data(contentsOf: url)
            importWorkouts(from: data)
        } catch {
            print("Failed to import workouts from file: \(error.localizedDescription)")
        }
    }
    
    private func importWorkouts(from data: Data) {
        configStore.importWorkouts(from: data)
        
        // Update current workout if needed
        if currentWorkout == nil || !configStore.workouts.contains(where: { $0.id == currentWorkout?.id }) {
            currentWorkout = configStore.workouts.first
        }
    }
}

struct WorkoutPickerView: View {
    let workouts: [Workout]
    let onSelect: (Workout) -> Void
    let onCreateNew: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(workouts) { workout in
                    Button {
                        onSelect(workout)
                        dismiss()
                    } label: {
                        Text(workout.name)
                    }
                }
                
                Button {
                    onCreateNew()
                    dismiss()
                } label: {
                    Label("New Workout", systemImage: "plus")
                }
            }
            .navigationTitle("Select Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(TrackConfigStore())
        .environment(SpotifyService())
}
