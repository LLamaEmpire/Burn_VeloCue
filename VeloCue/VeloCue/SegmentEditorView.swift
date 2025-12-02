//
//  SegmentEditorView.swift
//  VeloCue
//
//  Created by Sebastian Skora on 2025.
//  Segment editor - where coaches define what happens in each segment.
//

import SwiftUI

// bounds for segment editing - prevents segments from going outside track limits
struct SegmentEditorBounds {
    let minStart: Int  // earliest this segment can start
    let maxEnd: Int?   // latest this segment can end (nil = no limit)
    
    // unconstrained bounds - for when we don't care about limits
    static let unconstrained = SegmentEditorBounds(minStart: 0, maxEnd: nil)
}

// segment editor - edit a single segment's timing and properties
struct SegmentEditorView: View {
    @State private var segment: Segment  // the segment we're editing
    let onSave: (Segment) -> Void       // callback when user saves
    private let bounds: SegmentEditorBounds  // timing constraints
    @Environment(\.dismiss) private var dismiss
    @Environment(SpotifyService.self) private var spotifyService
    @State private var startTimeText: String = ""  // formatted start time for input
    @State private var endTimeText: String = ""    // formatted end time for input
    @State private var editingEvent: SegmentEvent?  // which event we're editing
    @State private var currentSpotifyPosition: Int = 0  // current Spotify playback
    
    init(
        segment: Segment,
        bounds: SegmentEditorBounds = .unconstrained,
        onSave: @escaping (Segment) -> Void
    ) {
        _segment = State(initialValue: segment)
        _startTimeText = State(initialValue: formatTime(segment.startTime))
        _endTimeText = State(initialValue: formatTime(segment.endTime))
        self.bounds = bounds
        self.onSave = onSave
    }
    
    private var maxEndValue: Int {
        bounds.maxEnd ?? Int.max
    }
    
    private var startRange: ClosedRange<Int> {
        let upper = max(bounds.minStart, maxEndValue - 1)
        return bounds.minStart...upper
    }
    
    private var endRange: ClosedRange<Int> {
        let lower = segment.startTime + 1
        let upper = max(lower, maxEndValue)
        return lower...upper
    }
    
    private var isValid: Bool {
        segment.startTime >= bounds.minStart &&
        segment.endTime <= maxEndValue &&
        segment.endTime > segment.startTime
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Label", text: $segment.label)
                    TextField("RPM Range", text: $segment.rpmRange)
                    Picker("Position", selection: $segment.position) {
                        ForEach(Position.allCases, id: \.self) { position in
                            Text(position.rawValue).tag(position)
                        }
                    }
                    HStack {
                        Text("Initial Resistance")
                        Spacer()
                        TextField("0 = Base", value: $segment.resistance, format: .number.decimalSeparator(strategy: .automatic))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .keyboardType(.decimalPad)
                    }
                    Picker("Power Shift", selection: $segment.powerShift) {
                        ForEach(PowerShift.allCases, id: \.self) { shift in
                            Text(shift.rawValue).tag(shift)
                        }
                    }
                }
                
                Section {
                    HStack {
                        Text("Start Time")
                        Spacer()
                        TextField("mm:ss", text: $startTimeText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .onChange(of: startTimeText) { _, newValue in
                                if let seconds = parseTime(newValue) {
                                    let clamped = max(startRange.lowerBound, min(startRange.upperBound, seconds))
                                    segment.startTime = clamped
                                    startTimeText = formatTime(clamped)
                                    
                                    if segment.endTime <= segment.startTime {
                                        segment.endTime = min(maxEndValue, segment.startTime + 1)
                                        endTimeText = formatTime(segment.endTime)
                                    }
                                }
                            }
                            .onChange(of: segment.startTime) { _, newValue in
                                startTimeText = formatTime(newValue)
                            }
                        Stepper("", value: $segment.startTime, in: startRange)
                            .labelsHidden()
                            .onChange(of: segment.startTime) { _, newValue in
                                if segment.endTime <= newValue {
                                    segment.endTime = min(maxEndValue, newValue + 1)
                                    endTimeText = formatTime(segment.endTime)
                                } else if segment.endTime > maxEndValue {
                                    segment.endTime = maxEndValue
                                    endTimeText = formatTime(segment.endTime)
                                }
                                startTimeText = formatTime(newValue)
                            }
                    }
                    
                    HStack {
                        Text("End Time")
                        Spacer()
                        TextField("mm:ss", text: $endTimeText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .onChange(of: endTimeText) { _, newValue in
                                if let seconds = parseTime(newValue) {
                                    let clamped = max(endRange.lowerBound, min(endRange.upperBound, seconds))
                                    segment.endTime = clamped
                                    endTimeText = formatTime(clamped)
                                }
                            }
                            .onChange(of: segment.endTime) { _, newValue in
                                if newValue > maxEndValue {
                                    segment.endTime = maxEndValue
                                    endTimeText = formatTime(segment.endTime)
                                } else {
                                    endTimeText = formatTime(newValue)
                                }
                            }
                        Stepper("", value: $segment.endTime, in: endRange)
                            .labelsHidden()
                            .onChange(of: segment.endTime) { _, newValue in
                                if newValue > maxEndValue {
                                    segment.endTime = maxEndValue
                                }
                                endTimeText = formatTime(segment.endTime)
                            }
                    }
                }
                
                if !isValid {
                    Section {
                        Text("Segment must stay between \(formatTime(bounds.minStart)) and \(bounds.maxEnd.map { formatTime($0) } ?? "track end")")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
                
                Section {
                    TextField("Cue (optional)", text: Binding(
                        get: { segment.cue ?? "" },
                        set: { segment.cue = $0.isEmpty ? nil : $0 }
                    ))
                    
                    Picker("Cue Font Size", selection: Binding(
                        get: { segment.cueFontSize },
                        set: { segment.cueFontSize = $0 }
                    )) {
                        Text("Default").tag(nil as CueFontSize?)
                        ForEach(CueFontSize.allCases, id: \.self) { size in
                            Text(size.rawValue.capitalized).tag(size as CueFontSize?)
                        }
                    }
                    
                    Picker("Cue Pulsing", selection: Binding(
                        get: { segment.cuePulsing },
                        set: { segment.cuePulsing = $0 }
                    )) {
                        Text("Default").tag(nil as Bool?)
                        Text("On").tag(true as Bool?)
                        Text("Off").tag(false as Bool?)
                    }
                    Picker("Leaderboard", selection: Binding(
                        get: { segment.leaderboard },
                        set: { segment.leaderboard = $0 }
                    )) {
                        Text("Use Track Default").tag(nil as Bool?)
                        Text("On").tag(true as Bool?)
                        Text("Off").tag(false as Bool?)
                    }
                    TextField("Light Settings (optional)", text: Binding(
                        get: { segment.lightSettings ?? "" },
                        set: { segment.lightSettings = $0.isEmpty ? nil : $0 }
                    ))
                }
                
                Section("Events") {
                    if segment.events.isEmpty {
                        Text("No events yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(segment.events) { event in
                            Button {
                                editingEvent = event
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("+\(formatTime(event.offset))")
                                        .font(.headline)
                                    if let cue = event.cue {
                                        Text(cue)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    let formatted = segment.formattedResistanceAndPowerShift(with: event)
                                    if formatted != segment.rpmRange {
                                        Text(formatted)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let position = event.position {
                                        Text("Position: \(position.rawValue)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                        .onDelete { offsets in
                            segment.events.remove(atOffsets: offsets)
                            segment.events.sort { $0.offset < $1.offset }
                        }
                    }
                    
                    HStack {
                        Button("Add Event") {
                            let segmentDuration = segment.endTime - segment.startTime
                            let lastEventOffset = segment.events.last?.offset ?? -1
                            let newOffset = min(segmentDuration - 1, lastEventOffset + 1)
                            editingEvent = SegmentEvent(
                                offset: max(0, newOffset)
                            )
                        }
                        
                        Spacer()
                        
                        Button("Add at Current Position") {
                            addEventAtCurrentPosition()
                        }
                        .disabled(!canAddEventAtCurrentPosition())
                    }
                }
            }
            .navigationTitle("Edit Segment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(segment)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .sheet(item: $editingEvent) { event in
                let segmentDuration = segment.endTime - segment.startTime
                let bounds = eventBounds(for: event, in: segment)
                SegmentEventEditorView(
                    event: event,
                    segmentDuration: segmentDuration,
                    minOffset: bounds.minOffset,
                    maxOffset: bounds.maxOffset
                ) { savedEvent in
                    if let index = segment.events.firstIndex(where: { $0.id == event.id }) {
                        segment.events[index] = savedEvent
                    } else {
                        segment.events.append(savedEvent)
                    }
                    segment.events.sort { $0.offset < $1.offset }
                    editingEvent = nil
                }
            }
        }
        .task {
            // Poll Spotify position frequently for accurate "Add Event at Current Position"
            while !Task.isCancelled {
                if spotifyService.isConnected {
                    currentSpotifyPosition = spotifyService.currentPosition
                }
                // Update every 0.1 seconds for accuracy
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }
    
    private func eventBounds(for event: SegmentEvent, in segment: Segment) -> (minOffset: Int, maxOffset: Int?) {
        // Check if this is a new event (not in the array yet)
        let isNewEvent = segment.events.firstIndex(where: { $0.id == event.id }) == nil
        
        if isNewEvent {
            // New event - place after last event
            let lastEventOffset = segment.events.last?.offset ?? -1
            let segmentDuration = segment.endTime - segment.startTime
            return (minOffset: max(0, lastEventOffset + 1), maxOffset: nil)
        }
        
        // Existing event - find its position and get bounds
        guard let index = segment.events.firstIndex(where: { $0.id == event.id }) else {
            // Fallback (shouldn't happen)
            return (minOffset: 0, maxOffset: nil)
        }
        
        let previousEventOffset = index == 0 ? -1 : segment.events[index - 1].offset
        let nextEventOffset = index == segment.events.count - 1 ? nil : segment.events[index + 1].offset
        
        let minOffset = max(0, previousEventOffset + 1)
        let maxOffset = nextEventOffset.map { $0 - 1 }
        
        return (minOffset: minOffset, maxOffset: maxOffset)
    }
    
    private func canAddEventAtCurrentPosition() -> Bool {
        guard spotifyService.isConnected else { return false }
        
        // Use the frequently updated position
        let currentTime = currentSpotifyPosition
        // Check if current time is within the segment range
        return currentTime >= segment.startTime && currentTime < segment.endTime
    }
    
    private func addEventAtCurrentPosition() {
        guard spotifyService.isConnected else { return }
        
        // Force a fresh fetch of position right now for accuracy
        Task {
            do {
                let freshTrack = try await spotifyService.fetchCurrentTrack()
                // Update our cached position immediately
                await MainActor.run {
                    currentSpotifyPosition = spotifyService.currentPosition
                    addEventAtPosition(currentSpotifyPosition)
                }
            } catch {
                // Fallback to cached position if fetch fails
                if canAddEventAtCurrentPosition() {
                    addEventAtPosition(currentSpotifyPosition)
                }
            }
        }
    }
    
    private func addEventAtPosition(_ currentTime: Int) {
        // Check if current time is within the segment range
        guard currentTime >= segment.startTime && currentTime < segment.endTime else { return }
        
        // Calculate offset from segment start
        let offset = currentTime - segment.startTime
        
        // Ensure offset is valid (within segment bounds)
        let segmentDuration = segment.endTime - segment.startTime
        let validOffset = max(0, min(offset, segmentDuration - 1))
        
        // Create new event at this offset (blank event, no editor opened)
        let newEvent = SegmentEvent(offset: validOffset)
        
        // Add event directly to segment
        segment.events.append(newEvent)
        segment.events.sort { $0.offset < $1.offset }
        
        // CRITICAL: Do NOT set editingEvent here - we want NO editor to open
        // The user can tap the event in the list later to edit it if needed
    }
}

#Preview {
    SegmentEditorView(
        segment: Segment(
            startTime: 10,
            endTime: 25,
            label: "Test Segment",
            rpmRange: "60–80"
        ),
        bounds: .init(minStart: 5, maxEnd: 40)
    ) { _ in }
}

