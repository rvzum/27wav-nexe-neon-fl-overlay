//
//  Animations.swift
//  NEXENeonOverlay
//
//  Shared timing helpers so every effect view derives its animation
//  durations from the same curve. Keeps "slow and pleasant, never
//  aggressive flicker" consistent across the frame glow, ambient light,
//  and corner accents.
//

import SwiftUI

enum NexeAnimations {

    /// Maps the 0...1 normalized animation-speed value to a breathing-cycle
    /// duration in seconds. Intentionally floors well above zero — even at
    /// the slowest setting the overlay should feel alive, not frozen.
    static func pulseDuration(baseDuration: Double, normalizedSpeed: Double) -> Double {
        let clamped = max(0.15, min(1.0, normalizedSpeed))
        // Slower requested speed -> longer duration. Speed 1.0 maps to
        // ~60% of the base duration; speed 0.15 maps to ~2.2x the base.
        let factor = 2.2 - (clamped * 1.6)
        return baseDuration * factor
    }

    static func breathingAnimation(baseDuration: Double, normalizedSpeed: Double) -> Animation {
        .easeInOut(duration: pulseDuration(baseDuration: baseDuration, normalizedSpeed: normalizedSpeed))
        .repeatForever(autoreverses: true)
    }

    static func travelAnimation(baseDuration: Double, normalizedSpeed: Double, travelMultiplier: Double) -> Animation {
        let duration = pulseDuration(baseDuration: baseDuration, normalizedSpeed: normalizedSpeed) * 2.0 / max(travelMultiplier, 0.1)
        return .linear(duration: duration).repeatForever(autoreverses: false)
    }
}
