# Spotify Integration - Implementation Guide

## Architecture Overview

The Spotify integration is designed with a clean separation of concerns:

### Components

1. **SpotifyService** (`SpotifyService.swift`)
   - Central service managing Spotify connection and state
   - Exposes: `isConnected`, `currentTrack`, `currentPosition`, `isPlaying`
   - Handles authentication and connection lifecycle
   - Provides `fetchCurrentTrack()` for reading currently playing track

2. **SpotifyPlaybackTimeSource** (`SpotifyPlaybackTimeSource.swift`)
   - Implements `PlaybackTimeSource` protocol
   - Reads playback position from `SpotifyService`
   - In read-only mode: `play()`, `pause()`, `seek()` are no-ops

3. **RideModeSelectionView** (`RideModeSelectionView.swift`)
   - UI for choosing between Simulated and Spotify modes
   - Handles Spotify connection flow
   - Switches between time sources based on selection

4. **RideView** (updated)
   - Detects read-only mode (`isReadOnly` computed property)
   - Disables controls in Spotify mode, shows info message instead
   - Hides scrubber in read-only mode

5. **ContentView** (updated)
   - Added "New Track from Spotify" menu option
   - Creates TrackConfig from currently playing Spotify track

## Current Status

✅ **Implemented:**
- Architecture and type structure
- Mode selection UI
- Read-only mode detection
- Control disabling in Spotify mode
- "New Track from Spotify" flow (UI complete)
- Error handling structure

⚠️ **Placeholder Implementation:**
- `SpotifyService.connect()` - Currently throws error (needs SDK integration)
- `SpotifyService.fetchCurrentTrack()` - Currently throws error (needs SDK integration)
- Position updates - Timer-based fallback (needs SDK subscription)

## To Complete Spotify Integration

### Step 1: Add Spotify iOS SDK

1. Add Spotify iOS SDK via Swift Package Manager or CocoaPods
   - Package URL: `https://github.com/spotify/ios-sdk`
   - Or use CocoaPods: `pod 'SpotifyiOS`

2. Import in `SpotifyService.swift`:
   ```swift
   import SpotifyAppRemote
   ```

### Step 2: Configure Spotify App

1. Register your app at [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Get your Client ID
3. Set redirect URI: `velocue://spotify-callback`
4. Update `SpotifyService.clientID` with your actual Client ID

### Step 3: Implement Connection

In `SpotifyService.connect()`:

```swift
func connect() async throws {
    guard !isConnected else { return }
    
    let configuration = SPTConfiguration(
        clientID: Self.clientID,
        redirectURL: Self.redirectURI
    )
    
    appRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)
    appRemote?.delegate = self
    
    // Request authorization
    appRemote?.authorizeAndPlayURI("")
    
    // Wait for connection callback
    // Set isConnected = true in delegate method
}
```

### Step 4: Implement Track Fetching

In `SpotifyService.fetchCurrentTrack()`:

```swift
func fetchCurrentTrack() async throws -> CurrentTrack {
    guard isConnected, let appRemote = appRemote else {
        throw SpotifyError.notConnected
    }
    
    return try await withCheckedThrowingContinuation { continuation in
        appRemote.playerAPI?.getPlayerState { result, error in
            if let error = error {
                continuation.resume(throwing: error)
                return
            }
            
            guard let playerState = result as? SPTAppRemotePlayerState,
                  let track = playerState.track else {
                continuation.resume(throwing: SpotifyError.noTrackPlaying)
                return
            }
            
            let currentTrack = CurrentTrack(
                name: track.name,
                uri: track.uri,
                duration: track.duration
            )
            continuation.resume(returning: currentTrack)
        }
    }
}
```

### Step 5: Implement Position Updates

Subscribe to player state updates:

```swift
func startPositionUpdates() {
    guard isConnected else { return }
    
    playerStateSubscription = appRemote?.playerAPI?.subscribe(toPlayerState: { [weak self] playerState in
        guard let self = self,
              let state = playerState as? SPTAppRemotePlayerState else { return }
        
        Task { @MainActor in
            self.currentPosition = Int(state.playbackPosition / 1000) // Convert ms to seconds
            self.isPlaying = state.isPaused == false
        }
    })
}
```

### Step 6: Add App Remote Delegate

Implement `SPTAppRemoteDelegate`:

```swift
extension SpotifyService: SPTAppRemoteDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        isConnected = true
        startPositionUpdates()
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        isConnected = false
        stopPositionUpdates()
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        isConnected = false
    }
}
```

### Step 7: Handle URL Callback

In `VeloCueApp.swift`, handle the redirect URI:

```swift
.onOpenURL { url in
    if url.scheme == "velocue" && url.host == "spotify-callback" {
        // Handle Spotify callback
        spotifyService.handleAuthCallback(url: url)
    }
}
```

## Testing

### Simulated Mode (Current)
- ✅ Works without Spotify SDK
- ✅ All controls functional
- ✅ Full playback simulation

### Spotify Mode (After SDK Integration)
- Connect to Spotify app
- Play a track in Spotify
- Start ride in Spotify mode
- Verify position updates match Spotify playback
- Test "New Track from Spotify" creates config with correct name/URI

## Notes

- The app compiles and runs in simulated mode without Spotify SDK
- All Spotify-related code is isolated in `SpotifyService` and `SpotifyPlaybackTimeSource`
- Read-only mode is properly detected and controls are disabled
- Error handling is in place for connection failures
- The architecture is ready for future milestones (playback control, Live Activity, etc.)

