//
//  SegmentEventEditorView.swift
//  VeloCue
//
//  Created by Sebastian Skora on 2025.
//  Event editor - where coaches add specific moments within segments.
//

import SwiftUI

// event editor - edit a single event that happens within a segment
struct SegmentEventEditorView: View {
    @State private var event: SegmentEvent  // the event we're editing
    let segmentDuration: Int  // total duration of the parent segment
    let minOffset: Int        // earliest this event can happen (from previous event + 1)
    let maxOffset: Int?       // latest this event can happen (to next event - 1, or nil)
    let onSave: (SegmentEvent) -> Void  // callback when user saves
    @Environment(\.dismiss) private var dismiss
    @State private var offsetText: String = ""  // formatted offset time for input
    
    init(
        event: SegmentEvent,
        segmentDuration: Int,
        minOffset: Int = 0,
        maxOffset: Int? = nil,
        onSave: @escaping (SegmentEvent) -> Void
    ) {
        _event = State(initialValue: event)
        self.segmentDuration = segmentDuration
        self.minOffset = minOffset
        self.maxOffset = maxOffset
        self.onSave = onSave
        _offsetText = State(initialValue: formatTime(event.offset))
    }
    
    private var maxOffsetValue: Int {
        maxOffset ?? (segmentDuration - 1)
    }
    
    private var offsetRange: ClosedRange<Int> {
        let upper = min(maxOffsetValue, segmentDuration - 1)
        return minOffset...upper
    }
    
    private var isValid: Bool {
        event.offset >= minOffset &&
        event.offset <= maxOffsetValue &&
        event.offset < segmentDuration
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Overrides") {
                    TextField("Cue", text: Binding(
                        get: { event.cue ?? "" },
                        set: { event.cue = $0.isEmpty ? nil : $0 }
                    ))
                    
                    Picker("Cue Font Size", selection: Binding(
                        get: { event.cueFontSize },
                        set: { event.cueFontSize = $0 }
                    )) {
                        Text("Default").tag(nil as CueFontSize?)
                        ForEach(CueFontSize.allCases, id: \.self) { size in
                            Text(size.rawValue.capitalized).tag(size as CueFontSize?)
                        }
                    }
                    
                    Picker("Cue Pulsing", selection: Binding(
                        get: { event.cuePulsing },
                        set: { event.cuePulsing = $0 }
                    )) {
                        Text("Default").tag(nil as Bool?)
                        Text("On").tag(true as Bool?)
                        Text("Off").tag(false as Bool?)
                    }
                    TextField("RPM Range", text: Binding(
                        get: { event.rpmRange ?? "" },
                        set: { event.rpmRange = $0.isEmpty ? nil : $0 }
                    ))
                    Picker("Position", selection: Binding(
                        get: { event.position },
                        set: { event.position = $0 }
                    )) {
                        Text("None").tag(nil as Position?)
                        ForEach([Position.standing, Position.seated, Position.either], id: \.self) { position in
                            Text(position.rawValue).tag(position as Position?)
                        }
                    }
                    HStack {
                        Text("Resistance")
                        Spacer()
                        TextField("0 = Base", value: Binding(
                            get: { event.resistance },
                            set: { event.resistance = $0 }
                        ), format: .number.decimalSeparator(strategy: .automatic))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .keyboardType(.decimalPad)
                    }
                    
                    Picker("Power Shift", selection: Binding(
                        get: { event.powerShift },
                        set: { event.powerShift = $0 }
                    )) {
                        Text("None").tag(nil as PowerShift?)
                        ForEach(PowerShift.allCases, id: \.self) { shift in
                            Text(shift.rawValue).tag(shift as PowerShift?)
                        }
                    }
                    Picker("Leaderboard", selection: Binding(
                        get: { event.leaderboard },
                        set: { event.leaderboard = $0 }
                    )) {
                        Text("Use Segment Default").tag(nil as Bool?)
                        Text("On").tag(true as Bool?)
                        Text("Off").tag(false as Bool?)
                    }
                    TextField("Light Settings (optional)", text: Binding(
                        get: { event.lightSettings ?? "" },
                        set: { event.lightSettings = $0.isEmpty ? nil : $0 }
                    ))
                }
                
                Section {
                    HStack {
                        Text("Offset")
                        Spacer()
                        TextField("mm:ss", text: $offsetText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .onChange(of: offsetText) { _, newValue in
                                if let seconds = parseTime(newValue) {
                                    let clamped = max(offsetRange.lowerBound, min(offsetRange.upperBound, seconds))
                                    event.offset = clamped
                                    offsetText = formatTime(clamped)
                                }
                            }
                            .onChange(of: event.offset) { _, newValue in
                                offsetText = formatTime(newValue)
                            }
                        Stepper("", value: $event.offset, in: offsetRange)
                            .labelsHidden()
                            .onChange(of: event.offset) { _, newValue in
                                offsetText = formatTime(newValue)
                            }
                    }
                    
                    if maxOffset != nil {
                        Text("Time from segment start (\(formatTime(minOffset)) to \(formatTime(maxOffsetValue)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Time from segment start (\(formatTime(minOffset)) to \(formatTime(segmentDuration - 1)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if !isValid {
                    Section {
                        if let max = maxOffset {
                            Text("Offset must be between \(formatTime(minOffset)) and \(formatTime(max))")
                                .foregroundStyle(.red)
                                .font(.caption)
                        } else {
                            Text("Offset must be between \(formatTime(minOffset)) and \(formatTime(segmentDuration - 1))")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(event)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}

#Preview {
    SegmentEventEditorView(
        event: SegmentEvent(
            offset: 10,
            cue: "Test cue",
            rpmRange: "80-90",
            position: .standing,
            resistance: 5.0,
            powerShift: .left
        ),
        segmentDuration: 30,
        minOffset: 5,
        maxOffset: 20
    ) { _ in }
}

