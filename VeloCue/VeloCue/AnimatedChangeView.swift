import SwiftUI

struct AnimatedChangeView: View {
    let value: String
    let isActive: Bool
    @Binding var flashCount: Int
    @Binding var showingGreen: Bool
    
    private var shouldFlash: Bool {
        isActive && flashCount > 0 && flashCount <= 3
    }
    
    private var scale: CGFloat {
        if shouldFlash {
            // Subtle scale pulse during flash
            return flashCount % 2 == 1 ? 1.05 : 1.0
        }
        return 1.0
    }
    
    private var opacity: Double {
        if shouldFlash {
            // Subtle opacity change during flash
            return flashCount % 2 == 1 ? 0.7 : 1.0
        }
        return 1.0
    }
    
    var body: some View {
        Text(value)
            .foregroundStyle(showingGreen && isActive ? .green : .primary)
            .scaleEffect(scale)
            .opacity(opacity)
            .animation(.easeInOut(duration: 0.4), value: flashCount)
    }
}

