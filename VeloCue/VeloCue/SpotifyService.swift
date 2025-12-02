//
//  SpotifyService.swift
//  VeloCue
//
//  Created by Sebastian Skora on 2025.
//  Spotify integration - read-only to avoid fucking up user's playback.
//

import Foundation
import Observation
import SpotifyiOS

// spotify service - connects to Spotify and reads playback state
// 
// IMPORTANT: This is READ-ONLY. We never control playback after authorization.
// The Spotify SDK is annoying and may switch devices during auth, but we try to minimize it.
// 
// ⚠️ SDK LIMITATION: authorizeAndPlayURI might switch playback device during auth
// This is a Spotify SDK limitation - it's designed for control, not just reading
// 
// After authorization:
// - We only read player state (track, position, isPlaying)
// - We only subscribe to state updates
// - We NEVER call: play, pause, resume, skip, seek, or any control methods
// 
// Authorization:
// - Uses authorizeAndPlayURI("") with empty string (minimizes device switching)
// - After auth, only calls: subscribe(toPlayerState:), getPlayerState, unsubscribe(toPlayerState:)
// 
// Note: If device switches during auth, user needs to manually switch back via Spotify Connect
// The app will then read from whatever device is active, without controlling anything
@MainActor
@Observable
class SpotifyService: NSObject {
    // MARK: - Configuration
    // TODO: Replace with your Spotify app credentials from Spotify Developer Dashboard
    static let clientID = "**************"
    static let redirectURI = URL(string: "velocue://spotify-callback")!
    
    // MARK: - State
    var isConnected: Bool = false
    var currentTrack: CurrentTrack?
    var currentPosition: Int = 0  // seconds
    var isPlaying: Bool = false
    
    // Expose appRemote connection status for scene phase handling
    var hasAppRemote: Bool {
        appRemote != nil
    }
    
    var appRemoteIsConnected: Bool {
        appRemote?.isConnected ?? false
    }
    
    private var appRemote: SPTAppRemote?
    private var playerStateCallback: SPTAppRemoteCallback? // Store the callback to unsubscribe
    private var connectionContinuation: CheckedContinuation<Void, Error>?
    private var reconnectAttempts: Int = 0
    private var maxReconnectAttempts: Int = 3
    private var reconnectTask: Task<Void, Never>?
    
    private let configuration: SPTConfiguration = {
        let config = SPTConfiguration(
            clientID: SpotifyService.clientID,
            redirectURL: SpotifyService.redirectURI
        )
        return config
    }()
    
    struct CurrentTrack {
        let name: String
        let uri: String
        let duration: Int?  // milliseconds, convert to seconds when needed
    }
    
    override init() {
        super.init()
        // Service initialized, connection happens on demand
    }
    
    // MARK: - Connection Management
    
    /// Connect to Spotify App Remote for READ-ONLY access
    /// 
    /// This method:
    /// - Performs App Remote authorization/connection
    /// - Attempts to preserve the original playback device
    /// - After connection, only subscribes to playerState updates
    /// - Music should continue playing on whatever device is active via Spotify Connect
    func connect() async throws {
        // Check if already connected
        if isConnected && appRemote?.isConnected == true {
            return
        }
        
        // Initialize appRemote if needed
        if appRemote == nil {
            appRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)
            appRemote?.delegate = self
        }
        
        // Check if already authorized and connected
        if appRemote?.isConnected == true {
            isConnected = true
            subscribeToPlayerState()
            return
        }
        
        // Need to authorize
        // NOTE: Unfortunately, the Spotify App Remote SDK's authorizeAndPlayURI method
        // will switch the active playback device to the iPhone during authorization.
        // This is a limitation of the SDK design.
        // 
        // We use empty string to minimize impact, but the device switch may still occur.
        // After connection, we only read state and never control playback.
        return try await withCheckedThrowingContinuation { continuation in
            connectionContinuation = continuation
            
            // Use empty string to authorize without playing a specific track
            // Note: This may still cause device switch during authorization
            appRemote?.authorizeAndPlayURI("")
        }
    }
    
    /// Handle redirect URL from Spotify authorization
    /// 
    /// READ-ONLY: Completes App Remote connection but DOES NOT start playback
    /// Music continues playing on whatever device is active via Spotify Connect
    func handleRedirectURL(_ url: URL) {
        // Handle the redirect URL from Spotify authorization
        guard url.scheme == "velocue" && url.host == "spotify-callback" else {
            print("SpotifyService: Ignoring URL with wrong scheme/host: \(url)")
            return
        }
        
        print("SpotifyService: Received redirect URL: \(url)")
        
        // Ensure appRemote is initialized
        if appRemote == nil {
            print("SpotifyService: Initializing appRemote")
            appRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)
            appRemote?.delegate = self
        }
        
        // Extract token from URL fragment
        // Format: velocue://spotify-callback#access_token=TOKEN&token_type=Bearer&expires_in=3600
        var extractedToken: String?
        
        if let fragment = url.fragment {
            print("SpotifyService: URL fragment: \(fragment)")
            let components = fragment.components(separatedBy: "&")
            for component in components {
                if component.hasPrefix("access_token=") {
                    let token = String(component.dropFirst("access_token=".count))
                    // URL decode the token (in case it's encoded)
                    extractedToken = token.removingPercentEncoding ?? token
                    print("SpotifyService: Extracted token (length: \(extractedToken?.count ?? 0))")
                    break
                }
            }
        }
        
        // Set the token if we extracted it
        if let token = extractedToken {
            appRemote?.connectionParameters.accessToken = token
            print("SpotifyService: Set access token on connection parameters")
        } else {
            print("SpotifyService: WARNING - No access token found in URL fragment")
        }
        
        // READ-ONLY: Connect with the token
        // This will NOT start playback or change the active device
        // The SDK will use the token we set, and we only subscribe to playerState
        print("SpotifyService: Attempting to connect (read-only mode)...")
        appRemote?.connect()
    }
    
    func disconnect() {
        stopPeriodicFetch()
        reconnectTask?.cancel()
        reconnectTask = nil
        reconnectAttempts = 0
        if let callback = playerStateCallback {
            appRemote?.playerAPI?.unsubscribe(toPlayerState: callback)
        }
        playerStateCallback = nil
        appRemote?.disconnect()
        // Don't clear appRemote - keep it for potential reconnection
        isConnected = false
        currentTrack = nil
        currentPosition = 0
        isPlaying = false
    }
    
    /// Manually trigger a reconnection attempt (useful for UI buttons)
    func reconnect() async throws {
        reconnectAttempts = 0 // Reset attempts for manual reconnect
        try await connect()
    }
    
    /// Start automatic reconnection attempts
    private func startReconnectAttempts() {
        reconnectTask?.cancel()
        reconnectTask = nil
        
        guard reconnectAttempts < maxReconnectAttempts else {
            print("SpotifyService: Max reconnection attempts reached. Please manually reconnect.")
            reconnectAttempts = 0 // Reset for next time
            return
        }
        
        reconnectTask = Task { @MainActor in
            while reconnectAttempts < maxReconnectAttempts && !Task.isCancelled {
                let delay = min(pow(2.0, Double(reconnectAttempts)), 8.0) // 2s, 4s, 8s max
                print("SpotifyService: Waiting \(Int(delay)) seconds before next reconnect attempt...")
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                if !Task.isCancelled {
                    reconnectAttempts += 1
                    print("SpotifyService: Reconnection attempt \(reconnectAttempts)/\(maxReconnectAttempts)...")
                    
                    // Try to reconnect using existing token if available, otherwise will need re-authorization
                    if let appRemote = self.appRemote, !appRemote.isConnected {
                        // If we have a token in connection parameters, try to connect directly
                        if appRemote.connectionParameters.accessToken != nil {
                            // Try direct connection with existing token
                            do {
                                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                                    self.connectionContinuation = continuation
                                    appRemote.connect()
                                }
                                if self.isConnected {
                                    print("SpotifyService: Reconnected successfully after \(reconnectAttempts) attempts.")
                                    break // Exit loop on success
                                }
                            } catch {
                                print("SpotifyService: Reconnection attempt \(reconnectAttempts) failed: \(error.localizedDescription)")
                            }
                        } else {
                            // No token - need to re-authorize (will require user interaction)
                            do {
                                try await self.connect()
                                if self.isConnected {
                                    print("SpotifyService: Reconnected successfully after \(reconnectAttempts) attempts.")
                                    break // Exit loop on success
                                }
                            } catch {
                                print("SpotifyService: Reconnection attempt \(reconnectAttempts) failed: \(error.localizedDescription)")
                            }
                        }
                    } else if self.isConnected {
                        // Already connected
                        break
                    }
                }
            }
            if !self.isConnected && !Task.isCancelled {
                print("SpotifyService: Failed to reconnect after \(maxReconnectAttempts) attempts.")
            }
            reconnectTask = nil
        }
    }
    
    /// Stop automatic reconnection attempts
    private func stopReconnectAttempts() {
        reconnectTask?.cancel()
        reconnectTask = nil
        reconnectAttempts = 0
    }
    
    /// Subscribe to player state updates (READ-ONLY)
    /// 
    /// Only reads player state. Does NOT call any playback control methods.
    private func subscribeToPlayerState() {
        guard let appRemote = appRemote, appRemote.isConnected else { return }
        
        // Create the callback for player state updates
        let callback: SPTAppRemoteCallback = { [weak self] (playerState: Any?, error: Error?) in
            guard let self = self else { return }
            
            if let error = error {
                print("Error in player state subscription: \(error.localizedDescription)")
                // Only reconnect if the connection is actually lost
                // App Remote can read from other devices, so transient subscription errors don't mean disconnect
                Task { @MainActor in
                    let isActuallyDisconnected = !(self.appRemote?.isConnected ?? false)
                    if self.isConnected && isActuallyDisconnected {
                        print("SpotifyService: Connection lost in subscription, will reconnect via disconnect delegate...")
                        // Don't reconnect here - let the disconnect delegate handle it with proper backoff
                        self.isConnected = false
                    } else {
                        // Transient error - connection is still active, just log it
                        print("SpotifyService: Transient subscription error (connection still active): \(error.localizedDescription)")
                    }
                }
                return
            }
            
            guard let playerState = playerState,
                  let state = playerState as? SPTAppRemotePlayerState else {
                return
            }
            
            Task { @MainActor in
                self.updateFromPlayerState(state)
            }
        }
        
        // Store the callback so we can unsubscribe later
        playerStateCallback = callback
        
        // READ-ONLY: Subscribe to player state updates (read-only, no playback control)
        appRemote.playerAPI?.subscribe(toPlayerState: callback)
        
        // Also fetch initial state (read-only)
        fetchPlayerState()
        
        // Set up periodic fetching as backup (every 1 second, read-only)
        startPeriodicFetch()
    }
    
    nonisolated(unsafe) private var periodicFetchTask: Task<Void, Never>?
    
    private func startPeriodicFetch() {
        periodicFetchTask?.cancel()
        periodicFetchTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                if isConnected && appRemote?.isConnected == true {
                    fetchPlayerState()
                }
            }
        }
    }
    
    private func stopPeriodicFetch() {
        periodicFetchTask?.cancel()
        periodicFetchTask = nil
    }
    
    /// Fetch current player state (READ-ONLY)
    /// 
    /// Only reads player state. Does NOT call any playback control methods.
    /// This can read from any device playing via Spotify Connect, not just the iPhone.
    private func fetchPlayerState() {
        // READ-ONLY: getPlayerState only reads state, never controls playback
        // This reads from whatever device is currently playing via Spotify Connect
        appRemote?.playerAPI?.getPlayerState { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching player state: \(error.localizedDescription)")
                // Only treat as connection error if it's a real transport/connection issue
                // Don't disconnect on transient errors - App Remote can read from other devices
                let errorString = error.localizedDescription.lowercased()
                let isRealConnectionError = errorString.contains("connection refused") || 
                                           errorString.contains("stream error") ||
                                           errorString.contains("end of stream") ||
                                           (errorString.contains("not connected") && !(self.appRemote?.isConnected ?? false))
                
                // Only mark as disconnected if it's a real connection error AND the appRemote is actually disconnected
                if isRealConnectionError && !(self.appRemote?.isConnected ?? false) {
                    print("SpotifyService: Real connection error detected - App Remote is disconnected")
                    Task { @MainActor in
                        // Only mark as disconnected if appRemote confirms it's disconnected
                        if self.isConnected {
                            self.isConnected = false
                        }
                    }
                } else {
                    // Transient error - just log it, don't disconnect
                    // App Remote can still read from other devices even if there's a transient error
                    print("SpotifyService: Transient error fetching player state (connection still active): \(error.localizedDescription)")
                }
                return
            }
            
            guard let result = result,
                  let state = result as? SPTAppRemotePlayerState else {
                return
            }
            
            Task { @MainActor in
                self.updateFromPlayerState(state)
            }
        }
    }
    
    /// Update internal state from player state (READ-ONLY)
    /// 
    /// Only reads and updates local state. Does NOT call any playback control methods.
    private func updateFromPlayerState(_ state: SPTAppRemotePlayerState) {
        // Update position (convert from milliseconds to seconds)
        // playbackPosition is UInt, convert to Int
        let newPosition = Int(state.playbackPosition) / 1000
        if currentPosition != newPosition {
            currentPosition = newPosition
        }
        
        // Update playing state
        let newPlayingState = !state.isPaused
        if isPlaying != newPlayingState {
            isPlaying = newPlayingState
        }
        
        // Update current track
        // track is not Optional, it's a non-optional property
        let track = state.track
        // duration is UInt, convert to Int
        let durationInt = track.duration > 0 ? Int(track.duration) : nil
        
        // Check if track actually changed before updating
        let newTrack = CurrentTrack(
            name: track.name,
            uri: track.uri,
            duration: durationInt
        )
        
        let trackChanged = currentTrack?.uri != newTrack.uri || currentTrack?.name != newTrack.name
        
        if trackChanged {
            print("SpotifyService: Track changed - Old: '\(currentTrack?.name ?? "none")' (\(currentTrack?.uri ?? "none")), New: '\(newTrack.name)' (\(newTrack.uri))")
            currentTrack = newTrack
        } else if currentTrack == nil {
            // First time setting track
            currentTrack = newTrack
        }
    }
    
    // MARK: - Track Information (READ-ONLY)
    
    /// Fetch current track information (READ-ONLY)
    /// 
    /// Only reads player state. Does NOT call any playback control methods.
    func fetchCurrentTrack() async throws -> CurrentTrack {
        guard isConnected, let appRemote = appRemote else {
            throw SpotifyError.notConnected
        }
        
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            // READ-ONLY: getPlayerState only reads state, never controls playback
            appRemote.playerAPI?.getPlayerState { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let result = result,
                      let playerState = result as? SPTAppRemotePlayerState else {
                    continuation.resume(throwing: SpotifyError.noTrackPlaying)
                    return
                }
                
                // track is not Optional, it's a non-optional property
                let track = playerState.track
                
                // duration is UInt, convert to Int
                let durationInt = track.duration > 0 ? Int(track.duration) : nil
                let currentTrack = CurrentTrack(
                    name: track.name,
                    uri: track.uri,
                    duration: durationInt
                )
                
                // Also update our cached currentTrack with the fresh data
                // This ensures the @Observable property updates and triggers view updates
                if let self = self {
                    Task { @MainActor in
                        self.updateFromPlayerState(playerState)
                    }
                }
                
                continuation.resume(returning: currentTrack)
            }
        }
    }
    
    // MARK: - Position Updates (READ-ONLY)
    
    /// Start position updates via player state subscription (READ-ONLY)
    /// 
    /// Only reads player state. Does NOT call any playback control methods.
    func startPositionUpdates() {
        // Position updates are handled via player state subscription (read-only)
        // This method is kept for compatibility but subscription is automatic
        guard isConnected else { return }
        subscribeToPlayerState()
    }
    
    /// Stop position updates (READ-ONLY)
    /// 
    /// Only unsubscribes from updates. Does NOT call any playback control methods.
    func stopPositionUpdates() {
        stopPeriodicFetch()
        // READ-ONLY: unsubscribe only stops reading, never controls playback
        if let callback = playerStateCallback {
            appRemote?.playerAPI?.unsubscribe(toPlayerState: callback)
        }
        playerStateCallback = nil
    }
}

// MARK: - SPTAppRemoteDelegate

extension SpotifyService: SPTAppRemoteDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        print("SpotifyService: Connection established successfully")
        isConnected = true
        
        // Reset reconnect attempts on successful connection
        reconnectAttempts = 0
        reconnectTask?.cancel()
        reconnectTask = nil
        
        // IMPORTANT: The App Remote SDK may have switched the playback device to iPhone
        // during authorization. Unfortunately, there's no direct way to transfer playback
        // back to another device using only the App Remote SDK (that requires Web API).
        // 
        // We can only ensure we never call playback control methods after this point.
        // The user may need to manually switch the device back via Spotify Connect.
        
        subscribeToPlayerState()
        
        // Resume continuation if waiting for connection
        connectionContinuation?.resume()
        connectionContinuation = nil
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        print("SpotifyService: Disconnected with error: \(error?.localizedDescription ?? "none")")
        let wasConnected = isConnected
        isConnected = false
        stopPositionUpdates()
        stopReconnectAttempts() // Ensure any existing reconnect task is cancelled
        
        // Try to reconnect automatically if it was an unexpected disconnect
        // This handles cases where the playback device changes and connection is lost
        if error != nil && self.appRemote != nil && wasConnected {
            print("SpotifyService: Connection lost (possibly due to device change), attempting automatic reconnection...")
            startReconnectAttempts()
        }
        
        // Fail continuation if waiting for connection
        if let continuation = connectionContinuation {
            continuation.resume(throwing: error ?? SpotifyError.connectionFailed)
            connectionContinuation = nil
        }
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        print("SpotifyService: Connection attempt failed: \(error?.localizedDescription ?? "unknown error")")
        if let error = error {
            print("SpotifyService: Error details: \(error)")
        }
        isConnected = false
        stopReconnectAttempts() // Ensure any existing reconnect task is cancelled
        
        // If connection failed, try to reconnect with exponential backoff
        if reconnectAttempts < maxReconnectAttempts {
            startReconnectAttempts()
        } else {
            print("SpotifyService: Max reconnection attempts reached. Please try connecting manually.")
        }
        
        // Fail continuation if waiting for connection
        if let continuation = connectionContinuation {
            continuation.resume(throwing: error ?? SpotifyError.connectionFailed)
            connectionContinuation = nil
        }
    }
}

enum SpotifyError: LocalizedError {
    case notConnected
    case noTrackPlaying
    case connectionFailed
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to Spotify"
        case .noTrackPlaying:
            return "No track is currently playing"
        case .connectionFailed:
            return "Failed to connect to Spotify"
        }
    }
}

