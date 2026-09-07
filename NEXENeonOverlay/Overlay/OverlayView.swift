//
//  OverlayView.swift
//  NEXENeonOverlay
//
//  The full-window SwiftUI composition rendered inside OverlayWindow.
//  Entirely decorative: the whole view stack sits behind
//  `.allowsHitTesting(false)` as a second guarantee (on top of the window's
//  own `ignoresMouseEvents = true`) that nothing here can ever intercept a
//  click meant for FL Studio.
//

import SwiftUI

struct OverlayView: View {
    @ObservedObject var settings: OverlaySettings

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AmbientLightView(theme: settings.theme, size: proxy.size, settings: settings)

                NeonFrameView(
                    theme: settings.theme,
                    thickness: settings.frameThickness,
                    intensity: settings.normalizedGlowIntensity,
                    animationSpeed: settings.normalizedAnimationSpeed,
                    animationConfig: settings.theme.animation
                )

                CornerAccentsView(
                    theme: settings.theme,
                    intensity: settings.normalizedGlowIntensity,
                    animationSpeed: settings.normalizedAnimationSpeed
                )

                if settings.particlesEnabled {
                    ParticleSystemView(theme: settings.theme, intensity: settings.normalizedGlowIntensity)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
        .background(Color.clear)
    }
}

/// Minimalist HUD-style accents in each corner. Kept short and inset from
/// the true corner so they never overlap FL Studio's own window-chrome
/// controls (traffic lights, resize handles).
struct CornerAccentsView: View {
    let theme: Theme
    let intensity: Double
    let animationSpeed: Double

    @State private var pulse: Bool = false

    private let armLength: CGFloat = 22
    private let inset: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                corner(at: CGPoint(x: inset, y: inset), flipX: false, flipY: false)
                corner(at: CGPoint(x: proxy.size.width - inset, y: inset), flipX: true, flipY: false)
                corner(at: CGPoint(x: inset, y: proxy.size.height - inset), flipX: false, flipY: true)
                corner(at: CGPoint(x: proxy.size.width - inset, y: proxy.size.height - inset), flipX: true, flipY: true)
            }
        }
        .onAppear {
            let duration = 3.2 / max(animationSpeed, 0.15)
            withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                pulse.toggle()
            }
        }
    }

    private func corner(at point: CGPoint, flipX: Bool, flipY: Bool) -> some View {
        let dotOpacity = 0.5 + (pulse ? 0.5 : 0.0) * intensity
        return Path { path in
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: flipX ? -armLength : armLength, y: 0))
        }
        .stroke(theme.primaryColor.color.opacity(0.55 * intensity + 0.15), lineWidth: 1.5)
        .overlay(
            Path { path in
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: 0, y: flipY ? -armLength : armLength))
            }
            .stroke(theme.primaryColor.color.opacity(0.55 * intensity + 0.15), lineWidth: 1.5)
        )
        .overlay(
            Circle()
                .fill(theme.glowColor.color)
                .frame(width: 3, height: 3)
                .shadow(color: theme.glowColor.color, radius: 4 * intensity)
                .opacity(dotOpacity)
        )
        .position(point)
    }
}
