//
//  RideView.swift
//  VeloCue
//
//  Created by Sebastian Skora on 2025.
//  Main ride screen - shows current cues and what's coming next.
//

import SwiftUI

// main ride view - what coaches see during class
struct RideView: View {
    @Bindable var viewModel: RideViewModel
    @Environment(\.dismiss) private var dismiss
    
    // green pulsing animation state - @State so SwiftUI can animate it directly
    @State private var pulseScale: CGFloat = 1.0
        
    private var currentSegmentId: UUID? {
        viewModel.cueState.currentSegment?.id
    }
    
    // Get changed fields from viewModel (read-only computed property)
    private var changedFields: Set<String> {
        viewModel._changedFields ?? []
    }
    
    // Get previous segment ID from viewModel (persists across view recreations)
    private var previousSegmentId: UUID? {
        get { viewModel._lastValidSegmentId }
        set { viewModel._lastValidSegmentId = newValue }
    }
    
    // Get pulsing state from viewModel (persists across view recreations)
    private var shouldPulse: Bool {
        viewModel._shouldPulse
    }
    
        
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                trackHeaderView
                studioSettingsView
                
                // Active segment area (scrollable if needed)
                ScrollView {
                    activeSegmentView
                }
                .frame(maxHeight: geometry.size.height * 0.75)
                
                // NEXT section - fixed at bottom quarter
                nextSectionView
                    .frame(maxHeight: geometry.size.height * 0.25)
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width > 100 {
                        dismiss()
                    }
                }
        )
        .navigationBarHidden(true)
    }
    
    // Helper to format PowerShift as lowercase with "mid" instead of "middle"
    private func formatPowerShift(_ powerShift: PowerShift) -> String {
        switch powerShift {
        case .left: return "left"
        case .middle: return "mid"
        case .right: return "right"
        }
    }
    
    // Helper to get font size based on CueFontSize
    private func cueFont(for fontSize: CueFontSize) -> Font {
        switch fontSize {
        case .small: return .title2
        case .normal: return .title
        case .large: return .largeTitle
        }
    }
    
    // Start cue pulsing animation
    private func startCuePulsing() {
        viewModel._cueShouldPulse = true
        
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            viewModel._cuePulseScale = 1.05
            viewModel._cuePulseOpacity = 0.7
        }
    }
    
    // Stop cue pulsing animation
    private func stopCuePulsing() {
        viewModel._cueShouldPulse = false
        
        withAnimation(.easeInOut(duration: 0.3)) {
            viewModel._cuePulseScale = 1.0
            viewModel._cuePulseOpacity = 1.0
        }
    }
    
    // MARK: - View Components
    
    private var trackHeaderView: some View {
        HStack {
            Text(viewModel.config.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            
            if let trackType = viewModel.config.trackType, let hrRange = trackType.heartRateRange {
                Text("•")
                    .foregroundStyle(.tertiary)
                Text(hrRange)
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
            
            Spacer()
            
            Text("\(formatTime(viewModel.currentTime)) / \(formatTime(viewModel.cueState.totalTrackTime))")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemGray6))
    }
    
    private var studioSettingsView: some View {
        Group {
            if let current = viewModel.cueState.currentSegment {
                let currentEvent = viewModel.cueState.currentEvent
                let effectiveLeaderboard = current.effectiveLeaderboard(with: currentEvent, trackDefault: viewModel.config.leaderboard)
                let effectiveLightSettings = current.effectiveLightSettings(with: currentEvent, trackDefault: viewModel.config.lightSettings)
                let leaderboardText = effectiveLeaderboard ? "On" : "Off"
                
                HStack {
                    // LB: GREEN if changed (and not first segment), WHITE if not
                    Text("LB: \(leaderboardText)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(changedFields.contains("leaderboard") ? Color.green : Color.primary)
                        .scaleEffect(changedFields.contains("leaderboard") && shouldPulse ? pulseScale : 1.0)
                    
                    Spacer()
                    Spacer()
                    
                    if let lightSettings = effectiveLightSettings, !lightSettings.isEmpty {
                        // Settings: GREEN if changed (and not first segment), WHITE if not
                        Text("Settings: \(lightSettings)")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(changedFields.contains("lightSettings") ? Color.green : Color.primary)
                            .scaleEffect(changedFields.contains("lightSettings") && shouldPulse ? pulseScale : 1.0)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(Color(uiColor: .systemGray6))
            } else {
                let leaderboardText = viewModel.config.leaderboard ? "On" : "Off"
                HStack {
                    Text("LB: \(leaderboardText)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    Spacer()
                    
                    if let lightSettings = viewModel.config.lightSettings, !lightSettings.isEmpty {
                        Text("Settings: \(lightSettings)")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(Color(uiColor: .systemGray6))
            }
        }
    }
    
    // Format resistance as "+N" or "BASE"
    private func formatResistanceDisplay(_ resistance: Double?) -> String {
        guard let r = resistance, r > 0 else { return "BASE" }
        if r == floor(r) {
            return "+\(Int(r))"
        } else {
            return "+\(String(format: "%.1f", r))"
        }
    }
    
    private var activeSegmentView: some View {
        VStack(spacing: 24) {
            if let current = viewModel.cueState.currentSegment {
                let currentEvent = viewModel.cueState.currentEvent
                let effectivePosition = current.effectivePosition(with: currentEvent)
                let effectiveRpm = current.effectiveRpmRange(with: currentEvent)
                let effectiveResistance = current.effectiveResistance(with: currentEvent)
                let effectivePowerShift = current.effectivePowerShift(with: currentEvent)
                let effectiveCue = current.effectiveCue(with: currentEvent)
                
                // Segment label - same size as position
                Text(current.label)
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                
                // Position (Seated/Standing) - GREEN if changed from previous segment
                Text(effectivePosition.rawValue)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(changedFields.contains("position") ? Color.green : Color.primary)
                    .scaleEffect(changedFields.contains("position") && shouldPulse ? pulseScale : 1.0)
                    .onAppear {
                        print("🎨 POSITION RENDER: \(effectivePosition.rawValue), changedFields: \(changedFields), shouldPulse: \(shouldPulse), pulseScale: \(pulseScale)")
                    }
                
                // RPM / Resistance / PowerShift - Clean grid layout
                activeSegmentGrid(
                    rpm: effectiveRpm,
                    resistance: effectiveResistance,
                    powerShift: effectivePowerShift
                )
                
                // Cue - always primary (white) with optional pulsing
                if let cue = effectiveCue, !cue.isEmpty {
                    let cueFontSize = current.effectiveCueFontSize(with: currentEvent, trackDefault: viewModel._currentCueFontSize)
                    let shouldPulse = current.effectiveCuePulsing(with: currentEvent, trackDefault: viewModel.config.cuePulsing)
                    
                    Text(cue)
                        .font(cueFont(for: cueFontSize))
                        .foregroundStyle(.primary)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                        .scaleEffect(shouldPulse ? viewModel._cuePulseScale : 1.0)
                        .opacity(shouldPulse ? viewModel._cuePulseOpacity : 1.0)
                        .onAppear {
                            if shouldPulse {
                                startCuePulsing()
                            }
                        }
                        .onChange(of: shouldPulse) { _, newValue in
                            if newValue {
                                startCuePulsing()
                            } else {
                                stopCuePulsing()
                            }
                        }
                }
                
                // Huge countdown
                VStack(spacing: 8) {
                    let segmentDuration = current.endTime - current.startTime
                    HStack(spacing: 4) {
                        Text("Time Remaining")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("(\(formatTime(segmentDuration)) Total)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    
                    Text(formatTime(viewModel.cueState.timeRemaining))
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundStyle(viewModel.cueState.timeRemaining <= 5 ? .red : .primary)
                        .contentTransition(.numericText())
                }
                .padding(.vertical, 16)
            } else {
                Text("No active segment")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .onAppear {
            // Initialize first segment values if we have a current segment
            if let current = viewModel.cueState.currentSegment {
                let currentEvent = viewModel.cueState.currentEvent
                print("🔄 INITIALIZING FIRST SEGMENT VALUES")
                viewModel._previousSegmentId = current.id
                viewModel._previousPosition = current.effectivePosition(with: currentEvent)
                viewModel._previousRpm = current.effectiveRpmRange(with: currentEvent)
                viewModel._previousResistance = current.effectiveResistance(with: currentEvent)
                viewModel._previousPowerShift = current.effectivePowerShift(with: currentEvent)
                viewModel._previousLeaderboard = current.effectiveLeaderboard(with: currentEvent, trackDefault: viewModel.config.leaderboard)
                viewModel._previousLightSettings = current.effectiveLightSettings(with: currentEvent, trackDefault: viewModel.config.lightSettings)
                viewModel._lastValidSegmentId = current.id
                print("🔄 STORED INITIAL VALUES: pos=\(viewModel._previousPosition?.rawValue ?? "nil"), rpm=\(viewModel._previousRpm ?? "nil")")
            }
        }
        .onChange(of: currentSegmentId) { oldValue, newValue in
            print("🔄 SEGMENT CHANGE: \(oldValue?.uuidString ?? "nil") -> \(newValue?.uuidString ?? "nil")")
            
            // Stop any ongoing green pulsing when segment changes
            if viewModel._shouldPulse {
                print("🔄 STOPPING PULSE DUE TO SEGMENT CHANGE")
                viewModel._pulseTimerTask?.cancel()
                withAnimation(.easeInOut(duration: 0.2)) {
                    pulseScale = 1.0
                }
                viewModel._shouldPulse = false
            }
            
            // If we're losing a segment (going to nil), store its values first
            if let oldSegmentId = oldValue, newValue == nil {
                print("🔄 STORING VALUES FOR ENDING SEGMENT")
                // We need to find the segment that just ended to store its values
                // This is tricky because we don't have it anymore, but we can try to get it from the track
                if let segment = viewModel.config.segments.first(where: { $0.id == oldSegmentId }) {
                    let event = viewModel.cueState.currentEvent // This might be nil now
                    viewModel._previousSegmentId = segment.id
                    viewModel._previousPosition = segment.effectivePosition(with: event)
                    viewModel._previousRpm = segment.effectiveRpmRange(with: event)
                    viewModel._previousResistance = segment.effectiveResistance(with: event)
                    viewModel._previousPowerShift = segment.effectivePowerShift(with: event)
                    viewModel._previousLeaderboard = segment.effectiveLeaderboard(with: event, trackDefault: viewModel.config.leaderboard)
                    viewModel._previousLightSettings = segment.effectiveLightSettings(with: event, trackDefault: viewModel.config.lightSettings)
                    print("🔄 STORED VALUES FOR SEGMENT \(oldSegmentId)")
                }
            }
            
            // If we have a current segment, process it
            if let current = viewModel.cueState.currentSegment {
                let currentEvent = viewModel.cueState.currentEvent
                
                // Check if we have a previous segment to compare to
                // We have previous values if any of the previous values are not nil
                let hasPreviousValues = viewModel._previousPosition != nil || 
                                       viewModel._previousRpm != nil || 
                                       viewModel._previousResistance != nil ||
                                       viewModel._previousPowerShift != nil
                
                print("🔄 hasPreviousValues: \(hasPreviousValues)")
                print("🔄 Previous values: pos=\(viewModel._previousPosition?.rawValue ?? "nil"), rpm=\(viewModel._previousRpm ?? "nil"), res=\(viewModel._previousResistance?.description ?? "nil"), shift=\(viewModel._previousPowerShift?.rawValue ?? "nil")")
                print("🔄 _lastValidSegmentId: \(viewModel._lastValidSegmentId?.uuidString ?? "nil")")
                if hasPreviousValues {
                    print("🔄 HAVE PREVIOUS SEGMENT")
                    var newChangedFields: Set<String> = []
                    
                    let currentPosition = current.effectivePosition(with: currentEvent)
                    let currentRpm = current.effectiveRpmRange(with: currentEvent)
                    let currentResistance = current.effectiveResistance(with: currentEvent)
                    let currentPowerShift = current.effectivePowerShift(with: currentEvent)
                    let currentLeaderboard = current.effectiveLeaderboard(with: currentEvent, trackDefault: viewModel.config.leaderboard)
                    let currentLightSettings = current.effectiveLightSettings(with: currentEvent, trackDefault: viewModel.config.lightSettings)
                    
                    // Get previous values from viewModel
                    let prevPosition = viewModel._previousPosition
                    let prevRpm = viewModel._previousRpm
                    let prevResistance = viewModel._previousResistance
                    let prevPowerShift = viewModel._previousPowerShift
                    let prevLeaderboard = viewModel._previousLeaderboard
                    let prevLightSettings = viewModel._previousLightSettings
                    
                    print("🔄 COMPARING: pos=\(prevPosition?.rawValue ?? "nil")->\(currentPosition.rawValue), rpm=\(prevRpm ?? "nil")->\(currentRpm), res=\(prevResistance?.description ?? "nil")->\(currentResistance?.description ?? "nil"), shift=\(prevPowerShift?.rawValue ?? "nil")->\(currentPowerShift.rawValue)")
                    
                    if prevPosition != currentPosition { newChangedFields.insert("position") }
                    if prevRpm != currentRpm { newChangedFields.insert("rpm") }
                    if prevResistance != currentResistance { newChangedFields.insert("resistance") }
                    if prevPowerShift != currentPowerShift { newChangedFields.insert("powerShift") }
                    if prevLeaderboard != currentLeaderboard { newChangedFields.insert("leaderboard") }
                    if prevLightSettings != currentLightSettings { newChangedFields.insert("lightSettings") }
                    
                    print("🔄 CHANGED FIELDS: \(newChangedFields)")
                    viewModel._changedFields = newChangedFields
                    
                    // Trigger pulse animation if anything changed
                    if !newChangedFields.isEmpty {
                        print("🔄 TRIGGERING PULSE")
                        viewModel._shouldPulse = true
                        
                        // Cancel any existing pulse timer
                        viewModel._pulseTimerTask?.cancel()
                        
                        // Calculate pulse duration (up to 10 seconds, or less if segment ends sooner)
                        let segmentTimeRemaining = current.endTime - viewModel.currentTime
                        let maxPulseDuration: TimeInterval = 10.0
                        let pulseDuration = min(Double(segmentTimeRemaining), maxPulseDuration)
                        
                        print("🔄 PULSE DURATION: \(pulseDuration)s (segment has \(segmentTimeRemaining)s remaining)")
                        
                        // Start continuous pulsing for the calculated duration
                        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            pulseScale = 1.1
                        }
                        
                        // Stop pulsing after the calculated duration using Task
                        viewModel._pulseTimerTask = Task {
                            try? await Task.sleep(nanoseconds: UInt64(pulseDuration * 1_000_000_000))
                            if !Task.isCancelled {
                                await MainActor.run {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        pulseScale = 1.0
                                    }
                                    viewModel._shouldPulse = false
                                }
                            }
                        }
                    }
                } else {
                    print("🔄 FIRST SEGMENT - NO GREEN")
                    // First segment - no green highlighting
                    viewModel._changedFields = []
                }
                
                // Store current values as previous for next comparison
                // This ensures that the next segment will compare to this one
                viewModel._previousSegmentId = current.id
                viewModel._previousPosition = current.effectivePosition(with: currentEvent)
                viewModel._previousRpm = current.effectiveRpmRange(with: currentEvent)
                viewModel._previousResistance = current.effectiveResistance(with: currentEvent)
                viewModel._previousPowerShift = current.effectivePowerShift(with: currentEvent)
                viewModel._previousLeaderboard = current.effectiveLeaderboard(with: currentEvent, trackDefault: viewModel.config.leaderboard)
                viewModel._previousLightSettings = current.effectiveLightSettings(with: currentEvent, trackDefault: viewModel.config.lightSettings)
                
                // Update last valid segment ID
                viewModel._lastValidSegmentId = current.id
            } else {
                print("🔄 NO CURRENT SEGMENT - gap detected")
                // Don't reset anything during the gap - just wait for next segment
            }
        }
        .onChange(of: viewModel._shouldPulse) { _, shouldPulse in
            print("🔄 PULSE STATE CHANGED: \(shouldPulse)")
            if !shouldPulse {
                // Reset animation when pulsing stops
                withAnimation(.easeInOut(duration: 0.2)) {
                    pulseScale = 1.0
                }
            }
        }
    }
    
    // Grid layout for RPM, Resistance, PowerShift - spread out for readability
    private func activeSegmentGrid(rpm: String, resistance: Double?, powerShift: PowerShift) -> some View {
        HStack(spacing: 0) {
            // RPM column
            VStack(spacing: 4) {
                Text("RPM")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                Text(rpm.isEmpty ? "-" : rpm)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(changedFields.contains("rpm") ? Color.green : Color.primary)
                    .scaleEffect(changedFields.contains("rpm") && shouldPulse ? pulseScale : 1.0)
            }
            .frame(maxWidth: .infinity)
            
            // Resistance column
            VStack(spacing: 4) {
                Text("Resistance")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                Text(formatResistanceDisplay(resistance))
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(changedFields.contains("resistance") ? Color.green : Color.primary)
                    .scaleEffect(changedFields.contains("resistance") && shouldPulse ? pulseScale : 1.0)
            }
            .frame(maxWidth: .infinity)
            
            // PowerShift column
            VStack(spacing: 4) {
                Text("Shift")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                Text(formatPowerShift(powerShift))
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(changedFields.contains("powerShift") ? Color.green : Color.primary)
                    .scaleEffect(changedFields.contains("powerShift") && shouldPulse ? pulseScale : 1.0)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
    }
    
    private var nextSectionView: some View {
        VStack(spacing: 8) {
            Text("NEXT")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            nextSectionContentView()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func nextSectionContentView() -> some View {
        let currentSegment = viewModel.cueState.currentSegment
        let currentEvent = viewModel.cueState.currentEvent
        let currentRpm = currentSegment?.effectiveRpmRange(with: currentEvent) ?? ""
        let currentResistance = currentSegment?.effectiveResistance(with: currentEvent)
        let currentPowerShift = currentSegment?.effectivePowerShift(with: currentEvent) ?? .left
        let currentPosition = currentSegment?.effectivePosition(with: currentEvent) ?? .either
        
        // Check if next event has changes
        if let nextEvent = viewModel.cueState.nextEvent,
           let current = viewModel.cueState.currentSegment,
           current.changesInEvent(nextEvent).hasAny,
           let timeUntil = viewModel.cueState.timeUntilNext {
            nextEventContentView(
                nextEvent: nextEvent,
                current: current,
                timeUntil: timeUntil,
                currentRpm: currentRpm,
                currentResistance: currentResistance,
                currentPowerShift: currentPowerShift,
                currentPosition: currentPosition
            )
        } else if let nextSegment = viewModel.cueState.nextSegment,
                  let timeUntil = viewModel.cueState.timeUntilNext {
            nextSegmentContentView(
                nextSegment: nextSegment,
                timeUntil: timeUntil,
                currentRpm: currentRpm,
                currentResistance: currentResistance,
                currentPowerShift: currentPowerShift,
                currentPosition: currentPosition
            )
        } else if let linkedTrack = viewModel.linkedTrack {
            linkedTrackContentView(linkedTrack: linkedTrack)
        } else {
            Text("End of track")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
    
    private func nextEventContentView(
        nextEvent: SegmentEvent,
        current: Segment,
        timeUntil: Int,
        currentRpm: String,
        currentResistance: Double?,
        currentPowerShift: PowerShift,
        currentPosition: Position
    ) -> some View {
        let changes = current.changesInEvent(nextEvent)
        let nextRpm = changes.rpmRange ?? currentRpm
        let nextResistance = changes.resistance ?? currentResistance
        let nextPowerShift = changes.powerShift ?? currentPowerShift
        let nextPosition = changes.position ?? currentPosition
        
        // Calculate which parts are different from current
        let differentParts: Set<String> = {
            var parts: Set<String> = []
            if nextRpm != currentRpm { parts.insert("rpm") }
            if nextResistance != currentResistance { parts.insert("resistance") }
            if nextPowerShift != currentPowerShift { parts.insert("powerShift") }
            if nextPosition != currentPosition { parts.insert("position") }
            return parts
        }()
        
        return HStack(alignment: .top, spacing: 12) {
            Text(formatTime(timeUntil))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.blue)
                .frame(minWidth: 60)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Event")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                nextRpmResistancePowerShiftLine(
                    rpm: nextRpm,
                    resistance: nextResistance,
                    powerShift: nextPowerShift,
                    differentParts: differentParts
                )
                
                nextPositionView(
                    position: nextPosition,
                    differentParts: differentParts
                )
                
                // Cue always secondary (excluded from color logic)
                if let cue = changes.cue {
                    Text(cue)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            // Duration column for event
            VStack(alignment: .trailing, spacing: 4) {
                Text("Duration")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(formatTime(nextEvent.offset))
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            .frame(minWidth: 80)
        }
    }
    
    private func nextSegmentContentView(
        nextSegment: Segment,
        timeUntil: Int,
        currentRpm: String,
        currentResistance: Double?,
        currentPowerShift: PowerShift,
        currentPosition: Position
    ) -> some View {
        let nextRpm = nextSegment.effectiveRpmRange(with: nil)
        let nextResistance = nextSegment.effectiveResistance(with: nil)
        let nextPowerShift = nextSegment.effectivePowerShift(with: nil)
        let nextPosition = nextSegment.effectivePosition(with: nil)
        let nextLeaderboard = nextSegment.effectiveLeaderboard(with: nil, trackDefault: viewModel.config.leaderboard)
        let nextLightSettings = nextSegment.effectiveLightSettings(with: nil, trackDefault: viewModel.config.lightSettings)
        
        // Calculate which parts are different from current
        let differentParts: Set<String> = {
            var parts: Set<String> = []
            if nextRpm != currentRpm { parts.insert("rpm") }
            if nextResistance != currentResistance { parts.insert("resistance") }
            if nextPowerShift != currentPowerShift { parts.insert("powerShift") }
            if nextPosition != currentPosition { parts.insert("position") }
            return parts
        }()
        
        return HStack(alignment: .top, spacing: 12) {
            Text(formatTime(timeUntil))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.blue)
                .frame(minWidth: 60)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(nextSegment.label)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                nextRpmResistancePowerShiftLine(
                    rpm: nextRpm,
                    resistance: nextResistance,
                    powerShift: nextPowerShift,
                    differentParts: differentParts
                )
                
                nextPositionView(
                    position: nextPosition,
                    differentParts: differentParts
                )
                
                if let cue = nextSegment.cue, !cue.isEmpty {
                    Text(cue)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                // LB and Settings line
                HStack(spacing: 8) {
                    Text("LB: \(nextLeaderboard ? "On" : "Off")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let lightSettings = nextLightSettings, !lightSettings.isEmpty {
                        Text("Settings: \(lightSettings)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Duration column
            VStack(alignment: .trailing, spacing: 4) {
                Text("Duration")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(formatTime(nextSegment.endTime - nextSegment.startTime))
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            .frame(minWidth: 80)
        }
    }
    
    private func nextRpmResistancePowerShiftLine(
        rpm: String,
        resistance: Double?,
        powerShift: PowerShift,
        differentParts: Set<String>
    ) -> some View {
        // Compact grid for NEXT section
        HStack(spacing: 16) {
            // RPM
            VStack(spacing: 2) {
                Text("RPM")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(rpm.isEmpty ? "-" : rpm)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(differentParts.contains("rpm") ? Color.red : Color.primary)
            }
            
            // Resistance
            VStack(spacing: 2) {
                Text("Res")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(formatResistanceDisplay(resistance))
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(differentParts.contains("resistance") ? Color.red : Color.primary)
            }
            
            // PowerShift
            VStack(spacing: 2) {
                Text("Shift")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(formatPowerShift(powerShift))
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(differentParts.contains("powerShift") ? Color.red : Color.primary)
            }
        }
    }
    
    private func nextPositionView(
        position: Position,
        differentParts: Set<String>
    ) -> some View {
        // Position: RED if different, WHITE if same
        Text(position.rawValue)
            .font(.body)
            .foregroundStyle(differentParts.contains("position") ? Color.red : Color.primary)
    }
    
    private func linkedTrackContentView(linkedTrack: TrackConfig) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Next Track:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(linkedTrack.name)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            
            if let firstSegment = linkedTrack.segments.first {
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("First Segment: \(firstSegment.label)")
                        .font(.body)
                        .fontWeight(.medium)
                    Text(firstSegment.formattedResistanceAndPowerShift(with: nil))
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Text(firstSegment.position.rawValue)
                        .font(.body)
                        .foregroundStyle(.secondary)
                    if let cue = firstSegment.cue {
                        Text(cue)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("No segments defined")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        RideView(
            viewModel: RideViewModel(
                config: TrackConfig(
                    name: "Sample Track",
                    spotifyURI: "spotify:track:example",
                    segments: [
                        Segment(
                            startTime: 0,
                            endTime: 42,
                            label: "Warm-up seated",
                            rpmRange: "",
                            position: .seated,
                            resistance: 0,
                            powerShift: .left,
                            cue: "Easy pace, focus on form"
                        ),
                        Segment(
                            startTime: 42,
                            endTime: 85,
                            label: "Standing climb",
                            rpmRange: "55–60 RPM",
                            position: .standing,
                            resistance: 3,
                            powerShift: .middle,
                            cue: "B2R, build intensity",
                            events: [
                                SegmentEvent(offset: 10, cue: "Add 2 clicks", resistance: 5, powerShift: .right)
                            ]
                        ),
                        Segment(
                            startTime: 85,
                            endTime: 120,
                            label: "Recovery",
                            rpmRange: "70–80 RPM",
                            position: .either,
                            resistance: 0,
                            powerShift: .left
                        )
                    ],
                    workoutId: UUID()
                ),
                timeSource: SimulatedPlaybackTimeSource(),
                store: TrackConfigStore()
            )
        )
        .environment(TrackConfigStore())
    }
}

