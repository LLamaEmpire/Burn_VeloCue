//
//  VeloCueApp.swift
//  VeloCue
//
//  Created by Sebastian Skora on 19.11.2025.
//

import SwiftUI
import Observation

@main
struct VeloCueApp: App {

    @State private var configStore = TrackConfigStore()
    @State private var spotifyService = SpotifyService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(configStore)
                .environment(spotifyService)
                .onOpenURL { url in
                    // Handle Spotify redirect URL
                    spotifyService.handleRedirectURL(url)
                }
                .background(ScenePhaseHandler(spotifyService: spotifyService))
        }
    }
}

// Helper view to handle scene phase changes
private struct ScenePhaseHandler: View {
    @Environment(\.scenePhase) private var scenePhase
    let spotifyService: SpotifyService
    
    var body: some View {
        Color.clear
            .onChange(of: scenePhase) { oldPhase, newPhase in
                // Reconnect to Spotify when app becomes active
                if newPhase == .active {
                    Task {
                        // Only reconnect if we have an appRemote instance but it's not connected
                        // This means we were previously connected but lost connection
                        if spotifyService.hasAppRemote && !spotifyService.appRemoteIsConnected {
                            try? await spotifyService.connect()
                        }
                    }
                }
            }
    }
}