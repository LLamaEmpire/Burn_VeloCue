import SwiftUI

/// View for selecting between simulated and Spotify playback modes
struct RideModeSelectionView: View {
    let config: TrackConfig
    let store: TrackConfigStore
    @Environment(SpotifyService.self) private var spotifyService
    @State private var selectedMode: PlaybackMode = .simulated
    @State private var showSpotifyError: Bool = false
    @State private var spotifyErrorMessage: String = ""
    @State private var isConnecting: Bool = false
    
    enum PlaybackMode {
        case simulated
        case spotify
    }
    
    var body: some View {
        Group {
            if selectedMode == .simulated {
                RideView(
                    viewModel: RideViewModel(
                        config: config,
                        timeSource: SimulatedPlaybackTimeSource(),
                        store: store
                    )
                )
            } else {
                // Spotify mode
                if spotifyService.isConnected {
                    RideView(
                        viewModel: RideViewModel(
                            config: config,
                            timeSource: SpotifyPlaybackTimeSource(spotifyService: spotifyService),
                            store: store
                        )
                    )
                } else {
                    // Connection screen
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
                                
                                Text("Connect to Spotify")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("Connect to Spotify to sync playback with your music")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Button(action: connectToSpotify) {
                                    Text("Connect")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.green)
                                        .cornerRadius(12)
                                }
                                .padding(.horizontal)
                                
                                Button(action: { selectedMode = .simulated }) {
                                    Text("Use Simulated Mode Instead")
                                        .font(.subheadline)
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                    .padding()
                    .navigationTitle(config.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .alert("Spotify Error", isPresented: $showSpotifyError) {
                        Button("OK", role: .cancel) { }
                    } message: {
                        Text(spotifyErrorMessage)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { selectedMode = .simulated }) {
                        Label("Simulated Mode", systemImage: "timer")
                        if selectedMode == .simulated {
                            Image(systemName: "checkmark")
                        }
                    }
                    Button(action: { 
                        selectedMode = .spotify
                        if !spotifyService.isConnected {
                            connectToSpotify()
                        }
                    }) {
                        Label("Spotify Mode", systemImage: "music.note")
                        if selectedMode == .spotify {
                            Image(systemName: "checkmark")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
    
    private func connectToSpotify() {
        isConnecting = true
        
        Task {
            do {
                try await spotifyService.connect()
                spotifyService.startPositionUpdates()
                await MainActor.run {
                    isConnecting = false
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    spotifyErrorMessage = error.localizedDescription
                    showSpotifyError = true
                }
            }
        }
    }
}

