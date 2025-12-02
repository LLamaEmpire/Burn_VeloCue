# VeloCue JSON Structure Documentation

This document explains the JSON structure for workouts, tracks, segments, and events so AI agents can generate valid workout files.

## Top-Level Structure

The JSON file is an **array of Workout objects**:

```json
[
  {
    "id": "uuid-string",
    "name": "Workout Name",
    "tracks": [...]
  }
]
```

## Workout Object

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",  // UUID (required)
  "name": "Morning Burn Class",                  // String (required)
  "tracks": [...]                                 // Array of TrackConfig (required)
}
```

## TrackConfig Object

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440001",  // UUID (required)
  "name": "Losing It (burn edit)",               // String (required)
  "spotifyURI": "spotify:track:4iV5W9uYEdYUVa79Axb7Rh", // String (required)
  "segments": [...],                              // Array of Segment (required)
  "nextTrackConfigId": "550e8400-e29b-41d4-a716-446655440002", // UUID? (optional - links to next track)
  "workoutId": "550e8400-e29b-41d4-a716-446655440000", // UUID (required - must match parent workout id)
  "trackType": "Warmup",                          // String? (optional: "Warmup", "Interval", "First Climb", "HIIT", "Isolation", "MeTime", "Speed", "Final Climb", "Cooldown")
  "leaderboard": true,                            // Bool (required, default: true = On)
  "lightSettings": "Dim lights, blue accent",     // String? (optional)
  "cueFontSize": "normal",                        // String (required, default: "normal")
  "cuePulsing": false                             // Bool (required, default: false)
}
```

## Segment Object

**IMPORTANT: Segments DO have IDs!** Each segment must have a unique UUID.

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440003",  // UUID (required)
  "startTime": 0,                                 // Int (required, seconds from track start)
  "endTime": 42,                                  // Int (required, seconds from track start)
  "label": "Warm-up seated",                      // String (required)
  "rpmRange": "",                                 // String (required, can be blank "")
  "position": "Either",                           // String (required: "Standing", "Seated", "Either")
  "resistance": 0.0,                              // Double? (optional, 0 = base, >0 = B+X, can be decimal like 2.5)
  "powerShift": "LEFT",                           // String (required: "LEFT", "MIDDLE", "RIGHT")
  "cue": "Easy pace, focus on form",              // String? (optional)
  "leaderboard": null,                            // Bool? (optional: null = use track default, true = On, false = Off)
  "lightSettings": null,                          // String? (optional)
  "cueFontSize": null,                            // String? (optional: null = use track default, "small", "normal", "large")
  "cuePulsing": null,                             // Bool? (optional: null = use track default, true = On, false = Off)
  "events": [...]                                 // Array of SegmentEvent (required, can be empty [])
}
```

## SegmentEvent Object

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440004",  // UUID (required)
  "offset": 10,                                   // Int (required, seconds from segment start)
  "cue": "Add 2 clicks",                        // String? (optional)
  "rpmRange": "80-90",                            // String? (optional)
  "position": "Standing",                         // String? (optional: "Standing", "Seated", "Either")
  "resistance": 5.0,                              // Double? (optional, 0 = base, >0 = B+X, can be decimal)
  "powerShift": "RIGHT",                          // String? (optional: "LEFT", "MIDDLE", "RIGHT")
  "leaderboard": false,                           // Bool? (optional: null = use segment default, true = On, false = Off)
  "lightSettings": "Bright white",                // String? (optional)
  "cueFontSize": null,                            // String? (optional: null = use segment default, "small", "normal", "large")
  "cuePulsing": null                              // Bool? (optional: null = use segment default, true = On, false = Off)
}
```

## ID Generation Rules

### All IDs Must Be Valid UUIDs

**CRITICAL: IDs must be valid UUID v4 format!**

Use standard UUID v4 format: `550e8400-e29b-41d4-a716-446655440000`

**Valid UUID format:**
- 8 hexadecimal digits
- Hyphen
- 4 hexadecimal digits
- Hyphen
- 4 hexadecimal digits
- Hyphen
- 4 hexadecimal digits
- Hyphen
- 12 hexadecimal digits

**Examples of VALID UUIDs:**
- `550e8400-e29b-41d4-a716-446655440000`
- `a1b2c3d4-e5f6-7890-abcd-ef1234567890`
- `00000000-0000-0000-0000-000000000001`

**Examples of INVALID UUIDs (will cause import to fail):**
- `TITH-S1-0001-0000-0000-000000000001` ❌ (contains letters that aren't hex)
- `segment-1` ❌ (not UUID format)
- `12345` ❌ (not UUID format)

**Important ID Requirements:**

1. **Workout IDs**: Each workout needs a unique UUID
2. **Track IDs**: Each track needs a unique UUID
3. **Segment IDs**: Each segment needs a unique UUID (even within the same track)
4. **Event IDs**: Each event needs a unique UUID (even within the same segment)
5. **workoutId in TrackConfig**: Must match the parent Workout's `id`
6. **nextTrackConfigId**: Must reference a valid TrackConfig `id` (can be in same or different workout)

**Note:** The import function will attempt to fix invalid UUIDs by generating new ones, but it's best to generate valid UUIDs from the start.

### Example: Generating IDs

```python
import uuid

# Generate IDs for a workout structure
workout_id = str(uuid.uuid4())
track1_id = str(uuid.uuid4())
track2_id = str(uuid.uuid4())
segment1_id = str(uuid.uuid4())
segment2_id = str(uuid.uuid4())
event1_id = str(uuid.uuid4())
event2_id = str(uuid.uuid4())

workout = {
    "id": workout_id,
    "name": "My Workout",
    "tracks": [
        {
            "id": track1_id,
            "name": "Track 1",
            "spotifyURI": "spotify:track:example1",
            "workoutId": workout_id,  # Must match workout.id
            "trackType": "Warmup",
            "leaderboard": True,
            "segments": [
                {
                    "id": segment1_id,  # Each segment needs unique ID
                    "startTime": 0,
                    "endTime": 30,
                    "label": "Segment 1",
                    "rpmRange": "",
                    "position": "Either",
                    "powerShift": "LEFT",
                    "events": [
                        {
                            "id": event1_id,  # Each event needs unique ID
                            "offset": 10,
                            "cue": "Event cue"
                        }
                    ]
                },
                {
                    "id": segment2_id,  # Different segment, different ID
                    "startTime": 30,
                    "endTime": 60,
                    "label": "Segment 2",
                    "rpmRange": "",
                    "position": "Standing",
                    "powerShift": "LEFT",
                    "events": [
                        {
                            "id": event2_id,  # Different event, different ID
                            "offset": 5
                        }
                    ]
                }
            ],
            "nextTrackConfigId": track2_id  # Links to next track
        },
        {
            "id": track2_id,
            "name": "Track 2",
            "spotifyURI": "spotify:track:example2",
            "workoutId": workout_id,  # Same workout
            "trackType": "Interval",
            "leaderboard": True,
            "segments": []
        }
    ]
}
```

## Complete Example

```json
[
  {
    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "name": "Sample Workout",
    "tracks": [
      {
        "id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",
        "name": "Warmup Track",
        "spotifyURI": "spotify:track:4iV5W9uYEdYUVa79Axb7Rh",
        "workoutId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
        "trackType": "Warmup",
        "leaderboard": true,
        "lightSettings": null,
        "cueFontSize": "normal",
        "cuePulsing": false,
        "nextTrackConfigId": "c3d4e5f6-a7b8-9012-cdef-123456789012",
        "segments": [
          {
            "id": "d4e5f6a7-b8c9-0123-def0-234567890123",
            "startTime": 0,
            "endTime": 30,
            "label": "Easy warmup",
            "rpmRange": "",
            "position": "Either",
            "resistance": null,
            "powerShift": "LEFT",
            "cue": "Start easy",
            "leaderboard": null,
            "lightSettings": null,
            "cueFontSize": null,
            "cuePulsing": null,
            "events": [
              {
                "id": "e5f6a7b8-c9d0-1234-ef01-345678901234",
                "offset": 15,
                "cue": "Increase pace",
                "rpmRange": null,
                "position": null,
                "resistance": 2.5,
                "powerShift": null,
                "leaderboard": null,
                "lightSettings": null,
                "cueFontSize": null,
                "cuePulsing": null
              }
            ]
          }
        ]
      },
      {
        "id": "c3d4e5f6-a7b8-9012-cdef-123456789012",
        "name": "Interval Track",
        "spotifyURI": "spotify:track:5jV6W9uYEdYUVa79Axb7Rh",
        "workoutId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
        "trackType": "Interval",
        "leaderboard": true,
        "lightSettings": null,
        "cueFontSize": "normal",
        "cuePulsing": false,
        "nextTrackConfigId": null,
        "segments": []
      }
    ]
  }
]
```

## Key Points for AI Agents

1. **Every object needs a unique UUID**: Workout, TrackConfig, Segment, and SegmentEvent all require unique IDs
2. **workoutId must match**: TrackConfig.workoutId must equal the parent Workout.id
3. **nextTrackConfigId is optional**: Can be null or reference another track's id
4. **Segments are sorted by startTime**: App will sort them, but it's good practice to provide them in order
5. **Events are sorted by offset**: App will sort them, but provide them in order
6. **All optional fields can be null**: Use `null` in JSON (not omitted)
7. **Enums are case-sensitive**: "Warmup" not "warmup", "LEFT" not "left"
8. **Resistance can be decimal**: Use 2.5, 3.0, etc. (0 = base, >0 = B+X)
9. **RPM can be blank**: Use empty string "" for no RPM specified
10. **Font size inheritance**: TrackConfig sets default, segments can override, events can override segment
11. **Pulsing inheritance**: TrackConfig sets default, segments can override, events can override segment
12. **Font size options**: "small" (title2), "normal" (title), "large" (largeTitle)
13. **Pulsing behavior**: true = gentle scale/opacity animation, false = no animation

## Validation Checklist

- [ ] All IDs are valid UUIDs
- [ ] All TrackConfig.workoutId match their parent Workout.id
- [ ] All nextTrackConfigId reference valid track IDs (or are null)
- [ ] All segments have unique IDs
- [ ] All events have unique IDs
- [ ] Segments are within track bounds (startTime < endTime)
- [ ] Events are within segment bounds (offset < segment duration)
- [ ] TrackType values are valid enum values
- [ ] Position values are valid: "Standing", "Seated", "Either"
- [ ] PowerShift values are valid: "LEFT", "MIDDLE", "RIGHT"
- [ ] CueFontSize values are valid: "small", "normal", "large" (or null for inheritance)
- [ ] CuePulsing values are valid: true, false (or null for inheritance)

