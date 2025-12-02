import Foundation

// Convert seconds → "mm:ss"
func formatTime(_ seconds: Int) -> String {
    let minutes = seconds / 60
    let remainingSeconds = seconds % 60
    return String(format: "%02d:%02d", minutes, remainingSeconds)
}

// Convert "mm:ss" → seconds
func parseTime(_ text: String) -> Int? {
    // Accept only "m:ss" or "mm:ss" format
    let components = text.split(separator: ":")
    
    // Must have exactly 2 components
    guard components.count == 2 else {
        return nil
    }
    
    // Parse minutes (1-2 digits)
    let minutesString = String(components[0])
    guard minutesString.count >= 1 && minutesString.count <= 2,
          let minutes = Int(minutesString),
          minutes >= 0 else {
        return nil
    }
    
    // Parse seconds (must be exactly 2 digits)
    let secondsString = String(components[1])
    guard secondsString.count == 2,
          let seconds = Int(secondsString),
          seconds >= 0 && seconds < 60 else {
        return nil
    }
    
    return minutes * 60 + seconds
}

