//
//  TrackConfigEditorView.swift
//  VeloCue
//
//  Created by Sebastian Skora on 2025.
//  Track editor - where coaches build their choreography.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

// track editor - main screen for building choreography for a single track
struct TrackConfigEditorView: View {
    @State var config: TrackConfig  // the track we're editing
    @Environment(TrackConfigStore.self) private var store
    @Environment(SpotifyService.self) private var spotifyService
    @Environment(\.dismiss) private var dismiss
    @State private var editingSegmentContext: SegmentEditContext?  // which segment we're editing
    @State private var selectedRideConfig: TrackConfig?
    @State private var currentSpotifyPosition: Int = 0  // current Spotify playback position
    @State private var showTrackImportPicker: Bool = false  // file import dialog
    @State private var showTrackImportClipboardAlert: Bool = false  // clipboard import dialog
    @State private var trackImportClipboardText: String = ""  // clipboard JSON content
    
    // context for editing a segment - keeps track of what we're editing and bounds
    private struct SegmentEditContext: Identifiable {
        var segment: Segment
        var bounds: SegmentEditorBounds
        
        var id: UUID { segment.id }
    }
    
    init(config: TrackConfig) {
        _config = State(initialValue: config)
    }
    
    var body: some View {
        Form {
            // Currently playing bar (if Spotify is playing this track)
            if spotifyService.isConnected,
               let currentTrack = spotifyService.currentTrack,
               currentTrack.uri == config.spotifyURI,
               spotifyService.isPlaying {
                Section {
                    HStack {
                        Image(systemName: "music.note")
                            .foregroundStyle(.green)
                        Text("Now Playing")
                            .font(.headline)
                        Spacer()
                        Text("\(formatTime(spotifyService.currentPosition))")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section {
                TextField("Name", text: $config.name)
                TextField("Spotify URI", text: $config.spotifyURI)
                Toggle("Leaderboard", isOn: $config.leaderboard)
                TextField("Light Settings", text: Binding(
                    get: { config.lightSettings ?? "" },
                    set: { config.lightSettings = $0.isEmpty ? nil : $0 }
                ))
                
                Picker("Default Cue Font Size", selection: $config.cueFontSize) {
                    ForEach(CueFontSize.allCases, id: \.self) { size in
                        Text(size.rawValue.capitalized).tag(size)
                    }
                }
                
                Toggle("Cue Pulsing", isOn: $config.cuePulsing)
                Menu {
                    Button {
                        config.trackType = nil
                    } label: {
                        Label("None", systemImage: config.trackType == nil ? "checkmark" : "")
                    }
                    ForEach(TrackType.allCases, id: \.self) { type in
                        Button {
                            config.trackType = type
                        } label: {
                            Label(type.rawValue, systemImage: config.trackType == type ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack {
                        Text("Track Type")
                        Spacer()
                        Text(config.trackType?.rawValue ?? "None")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section("Next Track") {
                if let nextTrackId = config.nextTrackConfigId,
                   let nextTrack = store.configs.first(where: { $0.id == nextTrackId }) {
                    HStack {
                        Text("Linked to:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(nextTrack.name)
                            .fontWeight(.medium)
                        Button {
                            config.nextTrackConfigId = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Menu {
                        ForEach(store.configs.filter { $0.id != config.id }) { track in
                            Button(track.name) {
                                config.nextTrackConfigId = track.id
                            }
                        }
                        if store.configs.filter({ $0.id != config.id }).isEmpty {
                            Text("No other tracks available")
                                .disabled(true)
                        }
                    } label: {
                        HStack {
                            Text("Link Next Track")
                                .foregroundStyle(.blue)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            Section("Segments") {
                if config.segments.isEmpty {
                    Text("No segments yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(config.segments) { segment in
                        Button {
                            presentEditor(for: segment)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(segment.label)
                                    .font(.headline)
                                Text("\(formatTime(segment.startTime)) → \(formatTime(segment.endTime))")
                                    .font(.caption)
                                HStack(spacing: 8) {
                                    Text(segment.rpmRange)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text("•")
                                        .foregroundStyle(.secondary)
                                    Text(segment.position.rawValue)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    .onDelete(perform: deleteSegments)
                }
                
                HStack {
                    Button {
                        // CRITICAL: Only open the editor, do NOT add segment directly
                        // The segment will only be added when user saves from the editor
                        presentNewSegmentEditor()
                    } label: {
                        Text("Add Segment")
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button {
                        // CRITICAL: Explicitly ensure editor is closed and add segment directly
                        editingSegmentContext = nil
                        addSegmentAtCurrentPosition()
                    } label: {
                        Text("Add at Current Position")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!spotifyService.isConnected || spotifyService.currentTrack == nil)
                }
            }
            
            // Export/Import buttons at the bottom
            Section {
                HStack(spacing: 12) {
                    // Export button
                    Button {
                        exportTrack()
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    // Import button
                    Menu {
                        Button {
                            showTrackImportPicker = true
                        } label: {
                            Label("Import from File", systemImage: "doc")
                        }
                        Button {
                            // Try to get JSON from clipboard
                            if let clipboardString = UIPasteboard.general.string,
                               let data = clipboardString.data(using: .utf8) {
                                importTrack(from: data)
                            } else {
                                showTrackImportClipboardAlert = true
                            }
                        } label: {
                            Label("Import from Clipboard", systemImage: "doc.on.clipboard")
                        }
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .navigationTitle("Edit Track Config")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    selectedRideConfig = config
                } label: {
                    Label("Start Ride", systemImage: "play.circle.fill")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    // Ensure segments are sorted before saving
                    config.segments.sort { $0.startTime < $1.startTime }
                    store.update(config)
                    // Navigate back to workout view
                    dismiss()
                }
            }
        }
        .navigationDestination(item: $selectedRideConfig) { config in
            RideModeSelectionView(
                config: config,
                store: store
            )
        }
        .fileImporter(
            isPresented: $showTrackImportPicker,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importTrackFromFile(url: url)
                }
            case .failure(let error):
                print("Track import failed: \(error.localizedDescription)")
            }
        }
        .alert("Import from Clipboard", isPresented: $showTrackImportClipboardAlert) {
            TextField("Paste JSON here", text: $trackImportClipboardText, axis: .vertical)
                .lineLimit(5...20)
            Button("Import") {
                if let data = trackImportClipboardText.data(using: .utf8) {
                    importTrack(from: data)
                    trackImportClipboardText = ""
                }
            }
            Button("Cancel", role: .cancel) {
                trackImportClipboardText = ""
            }
        } message: {
            Text("Paste the exported track JSON data here")
        }
        .sheet(item: $editingSegmentContext) { context in
            SegmentEditorView(
                segment: context.segment,
                bounds: context.bounds
            ) { savedSegment in
                applySavedSegment(savedSegment)
            }
            .environment(spotifyService)
        }
        .task {
            // Poll Spotify position frequently for accurate "Add at Current Position"
            while !Task.isCancelled {
                if spotifyService.isConnected {
                    currentSpotifyPosition = spotifyService.currentPosition
                }
                // Update every 0.1 seconds for accuracy
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }
    
    private func deleteSegments(at offsets: IndexSet) {
        config.segments.remove(atOffsets: offsets)
    }
    
    private func presentEditor(for segment: Segment) {
        let bounds = bounds(for: segment)
        editingSegmentContext = SegmentEditContext(segment: segment, bounds: bounds)
    }
    
    /// Present the segment editor for a NEW segment
    /// This finds the first available 15-second gap and opens the editor
    /// The segment is NOT added until the user saves from the editor
    private func presentNewSegmentEditor() {
        // IMPORTANT: This function ONLY opens the editor - it does NOT add the segment
        // The segment will be added in applySavedSegment() when the user saves
        
        // Sort segments by start time to ensure correct order
        let sortedSegments = config.segments.sorted { $0.startTime < $1.startTime }
        
        // Get track duration from Spotify (convert from milliseconds to seconds)
        // Default to a large number if not available
        let trackDuration: Int = {
            if let duration = spotifyService.currentTrack?.duration {
                return duration / 1000 // Convert milliseconds to seconds
            }
            // If no duration available, use a large default (or last segment end)
            return sortedSegments.last?.endTime ?? 300 // Default to 5 minutes if nothing
        }()
        
        // Default segment duration
        let defaultDuration = 15
        
        // Find the first available 15-second gap starting from 0
        var segmentStart = 0
        var segmentEnd = defaultDuration
        
        // If no segments exist, use 0-15
        if sortedSegments.isEmpty {
            segmentStart = 0
            segmentEnd = min(defaultDuration, trackDuration)
        } else {
            // Check if there's a gap at the start (0 to first segment)
            if let firstSegment = sortedSegments.first {
                if firstSegment.startTime >= defaultDuration {
                    // Gap at the start is big enough (first segment starts at or after 15)
                    segmentStart = 0
                    segmentEnd = defaultDuration
                } else {
                    // No gap at start, find first gap between segments or after last segment
                    var foundGap = false
                    
                    // First, check if there's a gap at the very start (before first segment)
                    // This handles the case where first segment doesn't start at 0
                    if firstSegment.startTime > 0 {
                        let gapAtStart = firstSegment.startTime
                        if gapAtStart >= defaultDuration {
                            // Gap at start is big enough
                            segmentStart = 0
                            segmentEnd = defaultDuration
                            foundGap = true
                        } else if gapAtStart > 0 {
                            // Small gap at start - use it
                            segmentStart = 0
                            segmentEnd = firstSegment.startTime - 1
                            foundGap = true
                        }
                    }
                    
                    // If no gap at start, check gaps between segments
                    if !foundGap {
                        for i in 0..<sortedSegments.count {
                            let currentSegment = sortedSegments[i]
                            let currentEnd = currentSegment.endTime
                            
                            // Find the next segment start (or track end if this is the last segment)
                            let nextSegmentStart: Int
                            if i < sortedSegments.count - 1 {
                                nextSegmentStart = sortedSegments[i + 1].startTime
                            } else {
                                nextSegmentStart = trackDuration
                            }
                            
                            // Calculate gap after current segment
                            // IMPORTANT: endTime is inclusive, so gap starts at endTime + 1
                            let gapStart = currentEnd + 1
                            let gapSize = nextSegmentStart - gapStart
                            
                            // Only consider gaps that are at least 1 second
                            if gapSize > 0 {
                                if gapSize >= defaultDuration {
                                    // Found a gap big enough for 15 seconds
                                    segmentStart = gapStart
                                    segmentEnd = gapStart + defaultDuration
                                    foundGap = true
                                    break
                                } else {
                                    // Gap exists but is smaller than 15 seconds - use it
                                    segmentStart = gapStart
                                    segmentEnd = nextSegmentStart - 1
                                    foundGap = true
                                    break
                                }
                            }
                        }
                    }
                    
                    // If no gap found between segments, add after the last segment
                    if !foundGap {
                        let lastSegment = sortedSegments.last!
                        segmentStart = lastSegment.endTime + 1
                        segmentEnd = min(segmentStart + defaultDuration, trackDuration)
                    }
                }
            }
        }
        
        // Ensure we have at least 1 second duration and don't exceed track duration
        if segmentEnd <= segmentStart {
            segmentEnd = min(segmentStart + 1, trackDuration)
        }
        if segmentEnd > trackDuration {
            segmentEnd = trackDuration
        }
        if segmentStart >= trackDuration {
            segmentStart = max(0, trackDuration - 1)
            segmentEnd = trackDuration
        }
        
        // Find the next segment for bounds calculation
        let nextSegmentStart = sortedSegments.first(where: { $0.startTime > segmentStart })?.startTime
        let bounds = SegmentEditorBounds(
            minStart: segmentStart,
            maxEnd: nextSegmentStart.map { $0 - 1 }
        )
        
        // Create a new segment template - this is NOT added to config.segments yet
        // It will only be added when the user saves from the editor
        let newSegment = Segment(
            startTime: segmentStart,
            endTime: segmentEnd,
            label: "New Segment",
            rpmRange: ""
        )
        
        // Set the editing context - this will trigger the sheet to open
        editingSegmentContext = SegmentEditContext(segment: newSegment, bounds: bounds)
    }
    
    private func applySavedSegment(_ savedSegment: Segment) {
        // This is called when user saves from the segment editor
        // For "Add Segment" flow: segment is new, so append it
        // For editing existing segment: update it
        // Do NOT adjust previous segments here - that logic is only for "Add at Current Position"
        if let index = config.segments.firstIndex(where: { $0.id == savedSegment.id }) {
            // Updating existing segment
            config.segments[index] = savedSegment
        } else {
            // Adding new segment from editor (user clicked "Add Segment" then saved)
            config.segments.append(savedSegment)
        }
        // CRITICAL: Sort segments by start time to ensure correct order for gap finding
        config.segments.sort { $0.startTime < $1.startTime }
        store.update(config)
        editingSegmentContext = nil
    }
    
    private func bounds(for segment: Segment) -> SegmentEditorBounds {
        guard let index = config.segments.firstIndex(where: { $0.id == segment.id }) else {
            return SegmentEditorBounds(minStart: 0, maxEnd: nil)
        }
        
        let previousEnd = index == 0 ? -1 : config.segments[index - 1].endTime
        let nextStart = index == config.segments.count - 1 ? nil : config.segments[index + 1].startTime
        
        let minStart = max(0, previousEnd + 1)
        let maxEnd = nextStart.map { $0 - 1 }
        
        return SegmentEditorBounds(minStart: minStart, maxEnd: maxEnd)
    }
    
    private func boundsForNewSegment() -> SegmentEditorBounds {
        let lastEnd = config.segments.last?.endTime ?? -1
        return SegmentEditorBounds(minStart: max(0, lastEnd + 1), maxEnd: nil)
    }
    
    private func addSegmentAtCurrentPosition() {
        guard spotifyService.isConnected,
              let currentTrack = spotifyService.currentTrack,
              currentTrack.uri == config.spotifyURI else {
            // Not connected or wrong track
            return
        }
        
        // CRITICAL: Ensure editor is closed before adding segment
        editingSegmentContext = nil
        
        // Force a fresh fetch of position right now for accuracy
        Task {
            do {
                _ = try await spotifyService.fetchCurrentTrack()
                // Update our cached position immediately after fetch
                await MainActor.run {
                    currentSpotifyPosition = spotifyService.currentPosition
                    addSegmentAtPosition(currentSpotifyPosition)
                    // Double-check editor is still closed after adding
                    editingSegmentContext = nil
                }
            } catch {
                // Fallback to cached position if fetch fails
                await MainActor.run {
                    addSegmentAtPosition(currentSpotifyPosition)
                    // Double-check editor is still closed after adding
                    editingSegmentContext = nil
                }
            }
        }
    }
    
    private func addSegmentAtPosition(_ currentTime: Int) {
        // IMPORTANT: This function is for "Add at Current Position" - it creates a segment
        // WITHOUT opening the editor. This allows quick segment marking while listening.
        
        // Sort segments to find if there's one before current time
        let sortedSegments = config.segments.sorted { $0.startTime < $1.startTime }
        
        // Check if there's ANY segment that starts before the current time
        let hasSegmentBeforeCurrent = sortedSegments.contains { segment in
            segment.startTime < currentTime
        }
        
        // If there's no segment that starts before current time, create an "Intro" segment from 0 to 1 second before current
        if !hasSegmentBeforeCurrent && currentTime > 0 {
            let introEnd = max(0, currentTime - 1)
            if introEnd > 0 {
                let introSegment = Segment(
                    startTime: 0,
                    endTime: introEnd,
                    label: "Intro",
                    rpmRange: "", // Empty
                    position: .either, // Default
                    resistance: nil, // Empty
                    powerShift: .left, // Default
                    cue: nil, // Empty
                    leaderboard: nil, // Use track default
                    lightSettings: nil // Empty
                )
                config.segments.append(introSegment)
            }
        }
        
        let segmentDuration = 10 // 10 seconds default
        let newSegmentStart = currentTime
        let newSegmentEnd = newSegmentStart + segmentDuration
        
        // Check if there's a previous segment to update
        // If the new segment starts after the last segment's start, update the last segment's end time
        if let lastSegment = config.segments.last, newSegmentStart > lastSegment.startTime {
            // Update the previous segment's end time to 1 second before the new segment
            if let index = config.segments.firstIndex(where: { $0.id == lastSegment.id }) {
                config.segments[index].endTime = max(newSegmentStart - 1, config.segments[index].startTime + 1)
            }
        }
        
        // Create new segment template (quick-add, no editor opened)
        let newSegment = Segment(
            startTime: newSegmentStart,
            endTime: newSegmentEnd,
            label: "Segment \(config.segments.count + 1)",
            rpmRange: "", // Blank RPM as default
            position: .either
        )
        
        config.segments.append(newSegment)
        config.segments.sort { $0.startTime < $1.startTime }
        store.update(config)
        
        // CRITICAL: Explicitly ensure editingSegmentContext is nil to prevent editor from opening
        // This is a quick-add operation - no editor should open
        editingSegmentContext = nil
    }
    
    // MARK: - Track Export/Import
    
    private func exportTrack() {
        // Get the track JSON data
        guard let jsonData = store.exportTrack(config) else {
            print("Failed to export track")
            return
        }
        
        // Copy to clipboard
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            UIPasteboard.general.string = jsonString
            print("Track exported to clipboard")
        }
    }
    
    private func importTrackFromFile(url: URL) {
        do {
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access file")
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            let data = try Data(contentsOf: url)
            importTrack(from: data)
        } catch {
            print("Failed to import track from file: \(error.localizedDescription)")
        }
    }
    
    private func importTrack(from data: Data) {
        guard let importedTrack = store.importTrack(from: data, preservingWorkoutId: config.workoutId) else {
            print("Failed to import track")
            return
        }
        
        // Replace current track with imported track
        config = importedTrack
        store.update(config)
    }
}

#Preview {
    NavigationStack {
        TrackConfigEditorView(
            config: TrackConfig(
                name: "Sample Track",
                spotifyURI: "spotify:track:example",
                workoutId: UUID()
            )
        )
        .environment(TrackConfigStore())
    }
}

