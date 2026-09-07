//
//  ParticleSystem.swift
//  NEXENeonOverlay
//
//  Optional, off-by-default ambient particles. Implemented with
//  CAEmitterLayer rather than a hand-driven per-frame loop: Core Animation
//  runs the emitter entirely on the render server / GPU compositor once
//  configured, so a SwiftUI Canvas + Timer approach (which would burn CPU
//  every frame recomputing positions) is unnecessary for something this
//  simple — CAEmitterLayer is the official, lightweight, "set it up once"
//  API for exactly this kind of subtle ambient particle effect.
//

import SwiftUI
import AppKit
import QuartzCore

struct ParticleSystemView: View {
    let theme: Theme
    /// 0...1 normalized glow intensity — scales particle opacity/brightness.
    let intensity: Double

    var body: some View {
        ParticleLayerRepresentable(color: theme.glowColor.nsColor, intensity: intensity)
            .allowsHitTesting(false)
    }
}

private struct ParticleLayerRepresentable: NSViewRepresentable {
    let color: NSColor
    let intensity: Double

    func makeNSView(context: Context) -> ParticleHostView {
        ParticleHostView(color: color, intensity: intensity)
    }

    func updateNSView(_ nsView: ParticleHostView, context: Context) {
        nsView.update(color: color, intensity: intensity)
    }
}

/// A plain NSView whose backing layer hosts a CAEmitterLayer sized to the
/// view's bounds. Kept as a thin AppKit view rather than trying to shoehorn
/// CAEmitterLayer configuration into SwiftUI directly.
final class ParticleHostView: NSView {
    private let emitterLayer = CAEmitterLayer()

    init(color: NSColor, intensity: Double) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.addSublayer(emitterLayer)
        configureEmitter(color: color, intensity: intensity)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        emitterLayer.frame = bounds
        emitterLayer.emitterPosition = CGPoint(x: bounds.midX, y: 0)
        emitterLayer.emitterSize = CGSize(width: bounds.width, height: 1)
    }

    func update(color: NSColor, intensity: Double) {
        configureEmitter(color: color, intensity: intensity)
    }

    private func configureEmitter(color: NSColor, intensity: Double) {
        emitterLayer.emitterShape = .line
        emitterLayer.emitterMode = .surface
        emitterLayer.renderMode = .additive

        // Spec: max 10-30 particles on screen at once, slow, subtle,
        // low-opacity. birthRate * lifetime ≈ steady-state particle count
        // (18 / 9 ≈ 2 born per second, ~9s lifetime -> ~18 on screen).
        // Written as plain literal expressions (no named Float/CGFloat
        // constant) so each one adopts whatever concrete numeric type
        // CAEmitterCell's property actually is, rather than risking a
        // Float/CGFloat mismatch from an explicitly-typed intermediate.
        let cell = CAEmitterCell()
        cell.birthRate = 18.0 / 9.0
        cell.lifetime = 9.0
        cell.lifetimeRange = 9.0 * 0.4
        cell.velocity = 6
        cell.velocityRange = 3
        cell.yAcceleration = -2 // drift slowly upward
        cell.emissionLongitude = .pi / 2 // upward
        cell.emissionRange = .pi / 10
        cell.scale = 0.05
        cell.scaleRange = 0.03
        cell.alphaSpeed = -1.0 / 9.0 // fade out over its lifetime
        cell.contents = Self.particleImage(color: color)
        cell.color = color.withAlphaComponent(CGFloat(0.5 * intensity)).cgColor

        emitterLayer.emitterCells = [cell]
    }

    /// A tiny soft round dot used as the particle sprite, generated once at
    /// runtime rather than shipped as an asset (keeps the effect entirely
    /// self-contained and themeable by tint color).
    private static func particleImage(color: NSColor) -> CGImage? {
        let diameter: CGFloat = 12
        let size = CGSize(width: diameter, height: diameter)
        let image = NSImage(size: size)
        image.lockFocus()
        if let context = NSGraphicsContext.current?.cgContext {
            let colors = [color.withAlphaComponent(0.9).cgColor, color.withAlphaComponent(0).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                context.drawRadialGradient(
                    gradient,
                    startCenter: CGPoint(x: diameter / 2, y: diameter / 2),
                    startRadius: 0,
                    endCenter: CGPoint(x: diameter / 2, y: diameter / 2),
                    endRadius: diameter / 2,
                    options: []
                )
            }
        }
        image.unlockFocus()
        var rect = CGRect(origin: .zero, size: size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}
