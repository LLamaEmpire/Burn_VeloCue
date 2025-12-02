//
//  TimeHelpers.swift
//  VeloCue
//
//  Created by Sebastian Skora on 2025.
//  Time formatting helpers - because dealing with seconds sucks.
//

import Foundation

// convert seconds to "mm:ss" format for display
func formatTime(_ seconds: Int) -> String {
    let minutes = seconds / 60
    let remainingSeconds = seconds % 60
    return String(format: "%02d:%02d", minutes, remainingSeconds)
}

// parse "mm:ss" text back to seconds for input validation
func parseTime(_ text: String) -> Int? {
    // accept only "m:ss" or "mm:ss" format - strict validation
    let components = text.split(separator: ":")
    
    // must have exactly 2 components
    guard components.count == 2 else {
        return nil
    }
    
    // parse minutes (1-2 digits, no negative numbers)
    let minutesString = String(components[0])
    guard minutesString.count >= 1 && minutesString.count <= 2,
          let minutes = Int(minutesString),
          minutes >= 0 else {
        return nil
    }
    
    // parse seconds (must be exactly 2 digits, 0-59)
    let secondsString = String(components[1])
    guard secondsString.count == 2,
          let seconds = Int(secondsString),
          seconds >= 0 && seconds < 60 else {
        return nil
    }
    
    return minutes * 60 + seconds
}

