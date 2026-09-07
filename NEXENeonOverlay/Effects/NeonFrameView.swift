//
//  NeonFrameView.swift
//  NEXENeonOverlay
//
//  The thin, glowing frame traced just inside the overlay window's edge —
//  visually, the border of FL Studio's window. Breathes slowly and sends a
//  faint point of light traveling around the perimeter. The frame's
//  geometry never moves or rotates (it must stay pixel-aligned to FL
//  Studio's window); only the gradient *paint* rotates, via
//  `AngularGradient`'s own `angle` parameter, which is the standard,
//  smoothly-wrapping way to animate a moving highlight around a static
//  shape in SwiftUI.
//

import SwiftUI

struct NeonFrameView: View {
    let theme: Theme
    /// 1...10 points, from the FRAME THICKNESS slider.
    let thickness: Double
    /// 0...1 normalized glow intensity.
    let intensity: Double
    /// 0...1 normalized animation speed.
    let animationSpeed: Double
    let animationConfig: ThemeAnimationConfig

    @State private var breathing: Bool = false
    @State private var travelAngle: Double = 0

    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(origin: .zero, size: proxy.size).insetBy(dx: CGFloat(thickness / 2), dy: CGFloat(thickness / 2))
            let breathIntensity = intensity * (1.0 - animationConfig.pulseDepth / 2 + (breathing ? animationConfig.pulseDepth / 2 : 0))

            ZStack {
                // Base neon line.
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .path(in: rect)
                    .stroke(theme.primaryColor.color.opacity(0.75), lineWidth: CGFloat(thickness))
                    .nexeGlow(color: theme.glowColor.color, intensity: breathIntensity)

                // Soft secondary tint for a two-tone "premium hardware" edge
                // rather than a single flat neon line.
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .path(in: rect)
                    .stroke(theme.secondaryColor.color.opacity(0.22), lineWidth: CGFloat(max(1, thickness * 0.4)))
                    .blendMode(.plusLighter)

                // Traveling highlight: a narrow bright band in an angular
                // gradient, rotating slowly around the fixed frame.
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .path(in: rect)
                    .stroke(
                        AngularGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .clear, location: 0.86),
                                .init(color: theme.glowColor.color.opacity(0.85 * intensity), location: 0.93),
                                .init(color: .clear, location: 1.0),
                            ],
                            center: .center,
                            angle: .degrees(travelAngle)
                        ),
                        lineWidth: CGFloat(thickness * 1.6)
                    )
                    .blur(radius: CGFloat(thickness * 0.5))
            }
        }
        .onAppear(perform: startAnimating)
        .onChange(of: animationSpeed) { _, _ in startAnimating() }
    }

    private func startAnimating() {
        withAnimation(NexeAnimations.breathingAnimation(
            baseDuration: animationConfig.basePulseDuration,
            normalizedSpeed: animationSpeed
        )) {
            breathing.toggle()
        }

        let travelDuration = NexeAnimations.pulseDuration(
            baseDuration: animationConfig.basePulseDuration * 4,
            normalizedSpeed: animationSpeed
        ) / max(animationConfig.borderTravelSpeed, 0.1)

        withAnimation(.linear(duration: travelDuration).repeatForever(autoreverses: false)) {
            travelAngle += 360
        }
    }
}
