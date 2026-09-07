//
//  OverlaySettings.swift
//  NEXENeonOverlay
//
//  User-configurable overlay settings. Persisted to UserDefaults so the
//  user's theme/intensity/animation/particle choices survive relaunch.
//

import Foundation
import Combine

/// Everything the user can control from the NEXE Visual Engine settings
/// window. This is the single source of truth read by every effect view.
final class OverlaySettings: ObservableObject {

    private enum Keys {
        static let overlayEnabled = "nexe.overlayEnabled"
        static let themeID = "nexe.themeID"
        static let glowIntensity = "nexe.glowIntensity"
        static let animationSpeed = "nexe.animationSpeed"
        static let frameThickness = "nexe.frameThickness"
        static let particlesEnabled = "nexe.particlesEnabled"
        static let effectMode = "nexe.effectMode"
        static let edgeSensitivity = "nexe.edgeSensitivity"
    }

    /// ENABLE VISUAL OVERLAY toggle.
    @Published var isOverlayEnabled: Bool {
        didSet { defaults.set(isOverlayEnabled, forKey: Keys.overlayEnabled) }
    }

    /// Currently selected theme.
    @Published var theme: Theme {
        didSet { defaults.set(theme.id, forKey: Keys.themeID) }
    }

    /// GLOW INTENSITY slider, 0...100.
    @Published var glowIntensity: Double {
        didSet { defaults.set(glowIntensity, forKey: Keys.glowIntensity) }
    }

    /// ANIMATION SPEED slider, 0...100.
    @Published var animationSpeed: Double {
        didSet { defaults.set(animationSpeed, forKey: Keys.animationSpeed) }
    }

    /// FRAME THICKNESS slider, 1...10 (points). Only used in OUTLINE ONLY mode.
    @Published var frameThickness: Double {
        didSet { defaults.set(frameThickness, forKey: Keys.frameThickness) }
    }

    /// PARTICLES toggle. Off by default per spec.
    @Published var particlesEnabled: Bool {
        didSet { defaults.set(particlesEnabled, forKey: Keys.particlesEnabled) }
    }

    /// EFFECT MODE: OUTLINE ONLY (default, no extra permission) vs LIVE EDGE
    /// GLOW (traces every button/panel/pattern-grid edge FL Studio itself
    /// draws; needs Screen Recording access — see ScreenCapturePermission).
    @Published var effectMode: EffectMode {
        didSet { defaults.set(effectMode.rawValue, forKey: Keys.effectMode) }
    }

    /// EDGE SENSITIVITY slider, 0...100 — only used in LIVE EDGE GLOW mode.
    @Published var edgeSensitivity: Double {
        didSet { defaults.set(edgeSensitivity, forKey: Keys.edgeSensitivity) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        self.isOverlayEnabled = defaults.object(forKey: Keys.overlayEnabled) as? Bool ?? true
        self.glowIntensity = defaults.object(forKey: Keys.glowIntensity) as? Double ?? 55
        self.animationSpeed = defaults.object(forKey: Keys.animationSpeed) as? Double ?? 40
        self.frameThickness = defaults.object(forKey: Keys.frameThickness) as? Double ?? 2
        self.particlesEnabled = defaults.object(forKey: Keys.particlesEnabled) as? Bool ?? false
        self.edgeSensitivity = defaults.object(forKey: Keys.edgeSensitivity) as? Double ?? 50

        if let savedID = defaults.string(forKey: Keys.themeID) {
            self.theme = Theme.byID(savedID)
        } else {
            self.theme = .nexeVoid
        }

        if let savedMode = defaults.string(forKey: Keys.effectMode), let mode = EffectMode(rawValue: savedMode) {
            self.effectMode = mode
        } else {
            self.effectMode = .outlineOnly
        }
    }

    /// Normalized 0...1 glow intensity, already scaled by the theme's own
    /// base intensity so each theme keeps its intended character across the
    /// slider's range.
    var normalizedGlowIntensity: Double {
        (glowIntensity / 100.0) * theme.intensity
    }

    /// Normalized 0...1 animation speed. 0 does not fully stop the
    /// animation (a static overlay looks broken/frozen); it floors at a
    /// slow, calm pace per the "no aggressive flicker" requirement.
    var normalizedAnimationSpeed: Double {
        max(0.15, animationSpeed / 100.0)
    }
}
