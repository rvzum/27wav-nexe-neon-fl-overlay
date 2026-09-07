//
//  GlowEffect.swift
//  NEXENeonOverlay
//
//  A reusable layered-bloom modifier. SwiftUI/Core Animation blur and
//  shadow rendering is already GPU-accelerated (backed by Core Image /
//  Metal under the hood on modern macOS), so stacking a few blurred,
//  low-opacity copies behind the sharp shape gives a convincing bloom
//  without a hand-rolled Metal render pipeline — the officially supported,
//  stable route the spec asks for ("Metal if necessary"; here it is not:
//  Core Animation's GPU-backed blur already satisfies the "use the GPU for
//  heavy effects" requirement).
//

import SwiftUI

struct GlowEffect: ViewModifier {
    let color: Color
    /// 0...1
    let intensity: Double

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.9 * intensity), radius: CGFloat(2 + 3 * intensity))
            .shadow(color: color.opacity(0.55 * intensity), radius: CGFloat(6 + 8 * intensity))
            .shadow(color: color.opacity(0.3 * intensity), radius: CGFloat(14 + 18 * intensity))
    }
}

extension View {
    /// Applies a soft multi-layer neon bloom in the given color, scaled by
    /// a 0...1 intensity value.
    func nexeGlow(color: Color, intensity: Double) -> some View {
        modifier(GlowEffect(color: color, intensity: intensity))
    }
}
