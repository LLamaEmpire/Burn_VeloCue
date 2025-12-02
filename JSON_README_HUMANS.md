# VeloCue - JSON Structure Guide for Coaches

This guide explains how to structure JSON files for VeloCue workouts, including all available features for creating engaging burn classes.

## Basic Structure

```json
{
  "workouts": [
    {
      "id": "workout-uuid",
      "name": "Morning Burn Class",
      "tracks": [
        {
          "id": "track-uuid", 
          "name": "Track Name",
          "spotifyURI": "spotify:track:...",
          "workoutId": "workout-uuid",
          "leaderboard": true,
          "lightSettings": "Warmup lights",
          "cueFontSize": "normal",
          "cuePulsing": false,
          "trackType": "Warmup",
          "segments": [
            {
              "id": "segment-uuid",
              "startTime": 0,
              "endTime": 60,
              "label": "Warmup",
              "rpmRange": "80-100 RPM",
              "position": "seated",
              "resistance": null,
              "powerShift": "left",
              "cue": "Easy warmup",
              "leaderboard": null,
              "lightSettings": null,
              "cueFontSize": null,
              "cuePulsing": null,
              "events": []
            }
          ]
        }
      ]
    }
  ]
}
```

## New Features

### 1. Cue Font Size Control

Control the size of cue text at three levels:

#### Track Level (Default)
```json
{
  "cueFontSize": "normal"  // Options: "small", "normal", "large"
}
```

#### Segment Level Override
```json
{
  "segments": [
    {
      "cueFontSize": "large",  // Override track default
      // ... other segment properties
    }
  ]
}
```

#### Event Level Override
```json
{
  "events": [
    {
      "cueFontSize": "small",  // Override segment and track
      // ... other event properties
    }
  ]
}
```

**Font Size Options:**
- `"small"`: Current size (title2)
- `"normal"`: +3 from current (title) - **default**
- `"large"`: +6 from current (largeTitle)

### 2. Cue Pulsing Animation

Make cues pulse with a gentle animation during segments:

#### Track Level (Default)
```json
{
  "cuePulsing": false  // Options: true, false
}
```

#### Segment Level Override
```json
{
  "segments": [
    {
      "cuePulsing": true,  // Override track default
      // ... other segment properties
    }
  ]
}
```

#### Event Level Override
```json
{
  "events": [
    {
      "cuePulsing": true,  // Override segment and track
      // ... other event properties
    }
  ]
}
```

**Pulsing Behavior:**
- When `true`: Cue gently pulses (grows 5% and fades to 70% opacity)
- Duration: 2-second cycles, continues until next event/segment
- When `false`: No pulsing effect

## Complete Example with All Features

```json
{
  "workouts": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "Advanced Interval Training",
      "tracks": [
        {
          "id": "550e8400-e29b-41d4-a716-446655440001",
          "name": "Losing It (spin edit)",
          "spotifyURI": "spotify:track:3Qm86XLflmIXVm1wcwkgDK",
          "workoutId": "550e8400-e29b-41d4-a716-446655440000",
          "leaderboard": true,
          "lightSettings": "Full class lights",
          "cueFontSize": "normal",
          "cuePulsing": false,
          "trackType": "Interval",
          "segments": [
            {
              "id": "550e8400-e29b-41d4-a716-446655440002",
              "startTime": 0,
              "endTime": 120,
              "label": "Warmup & Setup",
              "rpmRange": "80-100 RPM",
              "position": "seated",
              "resistance": null,
              "powerShift": "left",
              "cue": "Find your rhythm and get comfortable",
              "leaderboard": null,
              "lightSettings": null,
              "cueFontSize": null,
              "cuePulsing": false,
              "events": [
                {
                  "id": "550e8400-e29b-41d4-a716-446655440003",
                  "offset": 30,
                  "cue": "Increase resistance slightly",
                  "rpmRange": "85-95 RPM",
                  "position": "seated",
                  "resistance": 1.0,
                  "powerShift": null,
                  "leaderboard": null,
                  "lightSettings": null,
                  "cueFontSize": "large",
                  "cuePulsing": true
                },
                {
                  "id": "550e8400-e29b-41d4-a716-446655440004",
                  "offset": 90,
                  "cue": "Stand up for last 30 seconds",
                  "position": "standing",
                  "resistance": null,
                  "powerShift": null,
                  "leaderboard": null,
                  "lightSettings": null,
                  "cueFontSize": null,
                  "cuePulsing": true
                }
              ]
            },
            {
              "id": "550e8400-e29b-41d4-a716-446655440005",
              "startTime": 120,
              "endTime": 180,
              "label": "First Sprint",
              "rpmRange": "100-110 RPM",
              "position": "standing",
              "resistance": 2.5,
              "powerShift": "right",
              "cue": "30 second sprint!",
              "leaderboard": true,
              "lightSettings": "Sprint mode",
              "cueFontSize": "large",
              "cuePulsing": true,
              "events": [
                {
                  "id": "550e8400-e29b-41d4-a716-446655440006",
                  "offset": 30,
                  "cue": "Push harder!",
                  "resistance": 3.0,
                  "leaderboard": null,
                  "lightSettings": null,
                  "cueFontSize": "large",
                  "cuePulsing": true
                }
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

## Property Reference

### TrackConfig Properties
- `cueFontSize`: `"small" | "normal" | "large"` (default: `"normal"`)
- `cuePulsing`: `true | false` (default: `false`)

### Segment Properties
- `cueFontSize`: `"small" | "normal" | "large" | null` (null = use track default)
- `cuePulsing`: `true | false | null` (null = use track default)

### SegmentEvent Properties
- `cueFontSize`: `"small" | "normal" | "large" | null` (null = use segment/track default)
- `cuePulsing`: `true | false | null` (null = use segment/track default)

## Hierarchy & Inheritance

Settings follow this priority order:
1. **Event level** (highest priority)
2. **Segment level** 
3. **Track level** (default)

Example: If track has `cueFontSize: "normal"` and segment has `cueFontSize: "large"`, the segment will use "large". If an event then has `cueFontSize: "small"`, the event will use "small".

## Best Practices

### Font Size Usage
- **Small**: Standard cues, routine instructions
- **Normal**: Most cues, important instructions (default)
- **Large**: Critical cues, sprints, important transitions

### Pulsing Usage
- **False**: Regular segments, warmups, cooldowns (default)
- **True**: Important segments, sprints, intervals, key transitions

### Combining Features
Use large font size with pulsing for maximum impact on critical moments:
```json
{
  "cue": "FINAL SPRINT!",
  "cueFontSize": "large",
  "cuePulsing": true
}
```

## Visual Effects Summary

- **Green Highlighting**: Changed elements pulse green for up to 10 seconds when segments transition
- **Cue Color**: White by default (was gray)
- **Font Sizes**: Small (title2) → Normal (title) → Large (largeTitle)
- **Cue Pulsing**: Gentle scale and opacity animation when enabled
- **Smooth Transitions**: No "No active segment" flicker between segments

## Technical Notes

- All UUIDs should be valid v4 UUIDs
- Times are in seconds from track start
- Resistance values: `null` (base) or decimal numbers (e.g., 2.5 for B+2.5)
- Position values: `"seated" | "standing" | "either"`
- PowerShift values: `"left" | "right"`
- TrackType values: `"Warmup" | "Interval" | "First Climb" | "HIIT" | "Isolation" | "MeTime" | "Speed" | "Final Climb" | "Cooldown"`