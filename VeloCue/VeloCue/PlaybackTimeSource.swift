//
//  PlaybackTimeSource.swift
//  VeloCue
//
//  Created by Sebastian Skora on 2025.
//  Protocol for time sources - lets us swap simulated/real playback.
//

import Foundation

// protocol for time sources - lets us swap between simulated timer and real Spotify
// this is the dependency injection pattern I kept reading about
protocol PlaybackTimeSource: AnyObject {
    var currentTime: Int { get }  // current playback time in seconds
    var isPlaying: Bool { get }   // whether we're currently playing
    
    func play()                   // start playback
    func pause()                  // stop playback
    func seek(to time: Int)       // jump to specific time
}

