//
//  AmbientLightView.swift
//  NEXENeonOverlay
//
//  Very soft, large-radius glow pooling in the corners/edges of the
//  window — the "FL Studio is inside a futuristic terminal" ambient feel.
//  Pure gradients + blur, GPU-composited, extremely cheap to render.
//

import SwiftUI

struct AmbientLightView: View {
    let theme: Theme
    let size: CGSize
    @ObservedObject var settings: OverlaySettings

    @State private var breathing = false

    var body: some View {
        let intensity = settings.normalizedGlowIntensity
        let base = 0.10 + 0.10 * intensity
        let breathingBoost = breathing ? 0.04 * intensity : 0.0

        ZStack {
            corner(.topLeading, color: theme.primaryColor.color, opacity: base + breathingBoost)
            corner(.topTrailing, color: theme.secondaryColor.color, opacity: base * 0.8 + breathingBoost)
            corner(.bottomLeading, color: theme.secondaryColor.color, opacity: base * 0.8 + breathingBoost)
            corner(.bottomTrailing, color: theme.primaryColor.color, opacity: base + breathingBoost)
        }
        .blur(radius: max(size.width, size.height) * 0.06)
        .onAppear {
            let duration = NexeAnimations.pulseDuration(
                baseDuration: settings.theme.animation.basePulseDuration * 1.6,
                normalizedSpeed: settings.normalizedAnimationSpeed
            )
            withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                breathing.toggle()
            }
        }
    }

    private func corner(_ alignment: Alignment, color: Color, opacity: Double) -> some View {
        RadialGradient(
            gradient: Gradient(colors: [color.opacity(opacity), color.opacity(0)]),
            center: .center,
            startRadius: 0,
            endRadius: max(size.width, size.height) * 0.35
        )
        .frame(width: size.width * 0.6, height: size.height * 0.6)
        .frame(width: size.width, height: size.height, alignment: alignment)
    }
}
