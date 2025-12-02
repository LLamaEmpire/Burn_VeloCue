import SwiftUI

/// View that shows green and pulses/grows when it becomes active, then stays green
struct GreenActiveView: View {
    let value: String
    @State private var pulseScale: CGFloat = 1.0
    @State private var hasAnimated: Bool = false
    
    var body: some View {
        Text(value)
            .foregroundStyle(.green)
            .scaleEffect(pulseScale)
            .onAppear {
                // Pulse and grow when first becoming active
                if !hasAnimated {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        pulseScale = 1.2
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            pulseScale = 1.0
                        }
                        hasAnimated = true
                    }
                }
            }
    }
}

