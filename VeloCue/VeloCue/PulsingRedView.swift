import SwiftUI

/// View that pulses red slowly
struct PulsingRedView: View {
    let value: String
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        Text(value)
            .foregroundStyle(.red)
            .scaleEffect(pulseScale)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseScale = 1.15
                }
            }
            .onDisappear {
                withAnimation {
                    pulseScale = 1.0
                }
            }
    }
}

