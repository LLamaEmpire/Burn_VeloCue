//
//  RiderModeView.swift
//  VeloCue
//
//  Created by Sebastian Skora on 2025.
//  Auto-match Spotify tracks to choreography - the magic mode.
//

import SwiftUI

// rider mode - automatically matches whatever's playing on Spotify to your choreo
// this is the "it just works" mode for coaches who don't want to manually select tracks
struct RiderModeView: View {
    @Environment(TrackConfigStore.self) private var configStore
    @Environment(SpotifyService.self) private var spotifyService
    @State private var matchedConfig: TrackConfig?  // the track we found that matches Spotify
    @State private var isConnecting: Bool = false   // showing connection spinner
    @State private var showError: Bool = false      // show error dialog
    @State private var errorMessage: String = ""    // what went wrong
    @State private var lastTrackURI: String?        // track what we had before
    
    var body: some View {
        Group {
            if !spotifyService.isConnected {
                // Connection screen
                connectionView
            } else if let config = matchedConfig, let currentTrack = spotifyService.currentTrack, config.spotifyURI == currentTrack.uri {
                // Show ride view for matched track (only if still matching)
                // Use the track URI as the id to force view recreation when track changes
                RideView(
                    viewModel: RideViewModel(
                        config: config,
                        timeSource: SpotifyPlaybackTimeSource(spotifyService: spotifyService),
                        store: configStore
                    )
                )
                .id("\(config.id)-\(currentTrack.uri)") // Force view update when track changes
            } else {
                // No matching track found or track changed
                noMatchView
            }
        }
        .onAppear {
            if !spotifyService.isConnected {
                connectToSpotify()
            } else {
                checkForMatchingTrack()
            }
        }
        .onChange(of: spotifyService.currentTrack?.uri) { oldValue, newValue in
            // Track changed in Spotify - find new match
            print("RiderModeView: Track URI changed from \(oldValue ?? "nil") to \(newValue ?? "nil")")
            if oldValue != newValue {
                matchedConfig = nil // Clear match to force re-check
                checkForMatchingTrack()
            }
        }
        .onChange(of: spotifyService.currentTrack?.name) { oldValue, newValue in
            // Track name changed - also check for match
            print("RiderModeView: Track name changed from \(oldValue ?? "nil") to \(newValue ?? "nil")")
            if oldValue != newValue {
                matchedConfig = nil // Clear match to force re-check
                checkForMatchingTrack()
            }
        }
        .onChange(of: spotifyService.isConnected) { oldValue, newValue in
            if newValue {
                checkForMatchingTrack()
            }
        }
        .onChange(of: configStore.configs) { oldValue, newValue in
            // Configs changed - recheck match
            checkForMatchingTrack()
        }
        .task {
            // Periodic check every 1 second to catch any missed updates
            // Also force refresh the current track from Spotify
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if spotifyService.isConnected {
                    // Force refresh current track from Spotify (not just rely on subscription)
                    await refreshCurrentTrack()
                    checkForMatchingTrack()
                } else if spotifyService.hasAppRemote {
                    // Try to reconnect if we have appRemote but lost connection
                    try? await spotifyService.connect()
                }
            }
        }
        .alert("Spotify Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var connectionView: some View {
        VStack(spacing: 20) {
            if isConnecting {
                ProgressView()
                Text("Connecting to Spotify...")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "music.note")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)
                    
                    Text("Rider Mode")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Connect to Spotify to automatically match your playing track")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: connectToSpotify) {
                        Label("Connect to Spotify", systemImage: "music.note")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }
    
    private var noMatchView: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            
            Text("No Matching Track")
                .font(.title)
                .fontWeight(.bold)
            
            if let currentTrack = spotifyService.currentTrack {
                VStack(spacing: 8) {
                    Text("Currently Playing in Spotify:")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(currentTrack.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(currentTrack.uri)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }
                .padding()
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    Text("No track currently playing")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(12)
            }
            
            if !configStore.configs.isEmpty {
                VStack(spacing: 8) {
                    Text("Available Track Configs:")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    ForEach(configStore.configs.prefix(5)) { config in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(config.name)
                                .font(.body)
                                .fontWeight(.medium)
                            Text(config.spotifyURI)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    }
                    if configStore.configs.count > 5 {
                        Text("... and \(configStore.configs.count - 5) more")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding()
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(12)
            }
            
            Text("No track config found for the currently playing Spotify track.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("Create a track config from this song using \"New Track from Spotify\" in the main menu.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: checkForMatchingTrack) {
                Label("Refresh Match", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(uiColor: .systemBackground))
    }
    
    private func connectToSpotify() {
        isConnecting = true
        
        Task {
            do {
                try await spotifyService.connect()
                spotifyService.startPositionUpdates()
                await MainActor.run {
                    isConnecting = false
                    checkForMatchingTrack()
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func refreshCurrentTrack() async {
        // Force fetch fresh player state from Spotify
        // This ensures we have the most up-to-date track info
        do {
            let freshTrack = try await spotifyService.fetchCurrentTrack()
            print("RiderModeView: Refreshed track - '\(freshTrack.name)' (URI: \(freshTrack.uri))")
        } catch {
            print("RiderModeView: Failed to refresh track: \(error.localizedDescription)")
        }
    }
    
    private func checkForMatchingTrack() {
        guard spotifyService.isConnected,
              let currentTrack = spotifyService.currentTrack else {
            print("RiderModeView: Not connected or no current track")
            matchedConfig = nil
            return
        }
        
        print("RiderModeView: Checking for match - Current Spotify track: '\(currentTrack.name)' (URI: \(currentTrack.uri))")
        print("RiderModeView: Available configs: \(configStore.configs.map { "'\($0.name)' (\($0.spotifyURI))" }.joined(separator: ", "))")
        
        // Find matching track config by Spotify URI (exact match)
        let matchingConfig = configStore.configs.first { config in
            let matches = config.spotifyURI == currentTrack.uri
            if matches {
                print("RiderModeView: Found exact URI match: '\(config.name)'")
            }
            return matches
        }
        
        // If no exact match, try case-insensitive comparison
        let finalMatch = matchingConfig ?? configStore.configs.first { config in
            config.spotifyURI.lowercased() == currentTrack.uri.lowercased()
        }
        
        matchedConfig = finalMatch
        lastTrackURI = currentTrack.uri
        
        if finalMatch == nil {
            print("RiderModeView: ❌ No matching track config found for URI: \(currentTrack.uri)")
            print("RiderModeView: Current track name: '\(currentTrack.name)'")
        } else {
            print("RiderModeView: ✅ Matched track: '\(finalMatch!.name)' (URI: \(finalMatch!.spotifyURI))")
        }
    }
}

#Preview {
    RiderModeView()
        .environment(TrackConfigStore())
        .environment(SpotifyService())
}

