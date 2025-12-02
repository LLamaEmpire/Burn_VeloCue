# VeloCue Architecture

## What the Fuck Are We Building?

A cue system that allows for planning and playback of choreography for burn class. A tool that lets coaches mark segments, define what happens in class during those segments, then play it back in real time synced with Spotify playback.

## Core Problems We're Solving

1. **Choreo Planning** - Coaches need to plan their entire class beforehand, not just wing it. We need a way to structure the whole class with segments and events.
2. **Real-time Sync** - The planned choreo needs to sync perfectly with Spotify during class. No more "wait for the beat" or checking your phone.
3. **Visual Clarity** - During class, coaches need to see what's next without squinting at shitty studio lighting. Text needs to be big and obvious.
4. **Quick Editing** - Coaches should be able to tweak their choreo quickly between classes or even mid-session if needed.

## High-Level Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   RideView      │    │  RideViewModel  │    │   CueEngine     │
│  (SwiftUI UI)   │◄──►│ (State + Logic) │◄──►│ (Timing + Calc) │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  TrackConfig    │    │  Segment/Event  │    │  PlaybackTime   │
│   (JSON Data)   │    │   (Models)      │    │    (Protocol)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Data Flow ( Simple as Possible )

1. **JSON In** → Parse into models ( TrackConfig → Segment → SegmentEvent )
2. **Time Source** → CueEngine calculates current state based on playback time
3. **ViewModel** → Holds state, handles UI logic, persists across view recreations
4. **View** → Dumb UI that just displays what ViewModel tells it to

## Key Design Decisions

### Why SwiftUI + Observable?
I want to learn iOS development and writing this with Claude's support seems like a viable and fun project. My current understanding leads me to believe:
- SwiftUI is the modern way to build iOS apps - less boilerplate than the old UIKit stuff
- @Observable is the new hotness for state management, simpler than Combine
- I can focus on the actual choreo problems instead of fighting the framework
- It's declarative so I can think about what the UI should look like, not how to update it

### Why Separate CueEngine?
From what I've learned about good architecture, separation of concerns seems important:
- Timing logic gets complex fast with all the segment overlaps and event calculations
- Keeping it separate from UI code makes testing way easier - I can test the math without dealing with SwiftUI
- It feels more "professional" to have a pure logic layer that doesn't depend on iOS frameworks
- Maybe I could reuse it for a different platform someday (though probably not)

### Why Custom Time Source Protocol?
This seems like a good pattern for flexibility:
- I need to support both real Spotify playback and simulated playback for testing
- A protocol lets me swap between them without touching the CueEngine logic
- During development I don't want to wait 3 minutes just to test if a cue shows up at the right time
- It feels like the "dependency injection" thing I keep reading about

### Why So Many Override Properties?
Based on talking to actual coaches:
- They're picky as hell and want to override everything at every level
- Academy experience and my own original notes for my ride 
- Track sets defaults, segment can override for that whole segment, event can override just for that moment
- Nil-coalescing chain: event?.property ?? segment?.property ?? track.default
- This hierarchy pattern seems like a good way to handle defaults vs overrides

## State Management Strategy

### ViewModel Handles:
- Current playback time and active segment/event state
- Animation states (pulsing, transitions) - this was tricky to get right
- Previous segment data (for green highlighting when things change)
- All the @Observable properties that SwiftUI needs to watch

### Engine Handles:
- Time-based calculations - this is the math part that should stay pure
- Segment/event selection logic with the overlap handling
- No UI stuff here, just calculations based on time input

### View Handles:
- Display logic only - keep it as dumb as possible
- User input from the editor screens and controls
- Some animation state with @State where SwiftUI needs it directly

## The "Green Pulsing" Problem

When segments change, we need to highlight what changed. This is surprisingly tricky:

1. Store previous segment values in ViewModel
2. Compare with current segment values
3. Show changed fields in green
4. Pulse for up to 10 seconds (or less if segment ends)
5. Handle view recreations without losing animation state

Solution: Hybrid approach - trigger logic in ViewModel, animation state in @State, observer to sync them.

## File Structure

```
Models.swift          - All data structures, dumb as possible
CueEngine.swift       - Timing calculations, no UI code
RideViewModel.swift   - State management, UI logic
RideView.swift        - UI layer, as dumb as we can make it
Editor Views          - JSON editing interfaces
Store Classes         - Persistence ( data loading/saving )
```

## Testing Strategy

1. **Unit Tests** for CueEngine - pure functions, easy to test
2. **Integration Tests** for ViewModel - state changes, timing
3. **UI Tests** for critical user flows - not many, just the important ones

## Future Considerations

### Spotify Integration
- Will need real-time playback position
- Auth flow, token management
- Fallback to simulated mode for development

### Multi-coach Support
- Share workouts between coaches
- Cloud sync, version conflicts
- Probably not worth the headache initially

### iPad/Mobile Versions
- Same engine, different UI
- Responsive design considerations
- Touch vs keyboard interactions

## What We're NOT Doing

- No complex animations beyond the basics
- No social features, leaderboards in the app itself
- No cloud dependency for core functionality
- No over-engineering - keep it simple enough to maintain at 2am

## Development Philosophy

1. **Make it work, then make it pretty** - I'm still learning so get something functioning first
2. **Prefer simple solutions that actually work over complex "clean" solutions** - I can refactor later once I know more
3. **Test the timing logic religiously** - that's the core value of the app, if the timing is wrong the whole thing is useless
4. **Don't optimize prematurely** - SwiftUI is probably fast enough for what I need, I'll worry about performance later
5. **Leave good comments** - I'm going to forget why I did things this way, future me will thank present me

## What I'm Learning Along the Way

This project is teaching me:
- How SwiftUI state management actually works in a real app
- Why separation of concerns matters when things get complex
- How to handle timing and animation without going crazy
- That protocols are actually useful for flexibility
- When to use @State vs @Observable (still figuring this one out)

This architecture gives me a solid foundation that's simple enough to build while learning but flexible enough to handle the inevitable "oh shit, I need to change this" moments that come with learning a new platform.
