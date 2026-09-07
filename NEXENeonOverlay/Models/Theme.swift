//
//  Theme.swift
//  NEXENeonOverlay
//
//  Theme model for the NEXE Visual Engine. Every visual theme (color palette,
//  glow color, and default animation feel) is described by a single `Theme`
//  value. New themes can be added by appending another `Theme` literal to
//  `Theme.all` — nothing else in the app needs to change.
//

import SwiftUI
import AppKit

/// A Codable RGBA color that can be persisted to `UserDefaults` and converted
/// to both SwiftUI `Color` and `NSColor` / `CGColor` on demand.
struct ThemeColor: Codable, Equatable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Convenience initializer from a 0xRRGGBB hex literal.
    init(hex: UInt32, alpha: Double = 1.0) {
        self.red = Double((hex >> 16) & 0xFF) / 255.0
        self.green = Double((hex >> 8) & 0xFF) / 255.0
        self.blue = Double(hex & 0xFF) / 255.0
        self.alpha = alpha
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    var nsColor: NSColor {
        NSColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
    }

    func withAlpha(_ newAlpha: Double) -> ThemeColor {
        ThemeColor(red, green, blue, newAlpha)
    }
}

/// Per-theme animation feel. Kept separate from the numeric "Animation Speed"
/// slider in `OverlaySettings` so a theme can bias the base pacing (e.g.
/// SIGNAL RED breathes a little faster than NEXE VOID) while the user's
/// slider still scales the final result.
struct ThemeAnimationConfig: Codable, Equatable, Hashable {
    /// Base duration (seconds) of one full breathing/pulse cycle at
    /// animation speed = 50 (the slider midpoint).
    var basePulseDuration: Double
    /// How far the glow intensity swings during the pulse, as a fraction
    /// (0...1) of the configured glow intensity.
    var pulseDepth: Double
    /// Speed multiplier for the light that travels along the frame border.
    var borderTravelSpeed: Double

    static let standard = ThemeAnimationConfig(
        basePulseDuration: 4.2,
        pulseDepth: 0.35,
        borderTravelSpeed: 1.0
    )
}

/// A complete NEXE visual theme.
struct Theme: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let displayName: String
    let primaryColor: ThemeColor
    let secondaryColor: ThemeColor
    let glowColor: ThemeColor
    /// Base intensity multiplier baked into the theme (0...1). The user's
    /// Glow Intensity slider (0...100) multiplies this value.
    let intensity: Double
    let animation: ThemeAnimationConfig

    /// Subtle background tint used behind ambient ports of the settings UI
    /// so each theme feels distinct even outside the overlay itself.
    var backgroundTint: ThemeColor {
        ThemeColor(primaryColor.red, primaryColor.green, primaryColor.blue, 0.06)
    }
}

extension Theme {
    static let nexeVoid = Theme(
        id: "nexe.void",
        displayName: "NEXE VOID",
        primaryColor: ThemeColor(hex: 0xFF7A1A),   // neon orange
        secondaryColor: ThemeColor(hex: 0x8B5CF6), // subtle purple
        glowColor: ThemeColor(hex: 0xFF8C3A),
        intensity: 0.85,
        animation: ThemeAnimationConfig(basePulseDuration: 4.6, pulseDepth: 0.3, borderTravelSpeed: 0.9)
    )

    static let cyberBlue = Theme(
        id: "nexe.cyberblue",
        displayName: "CYBER BLUE",
        primaryColor: ThemeColor(hex: 0x2EA9FF),   // electric blue
        secondaryColor: ThemeColor(hex: 0x0B63C7),
        glowColor: ThemeColor(hex: 0x4FC3FF),
        intensity: 0.85,
        animation: ThemeAnimationConfig(basePulseDuration: 5.0, pulseDepth: 0.28, borderTravelSpeed: 1.0)
    )

    static let signalRed = Theme(
        id: "nexe.signalred",
        displayName: "SIGNAL RED",
        primaryColor: ThemeColor(hex: 0xFF3450),
        secondaryColor: ThemeColor(hex: 0x8A0F1E),
        glowColor: ThemeColor(hex: 0xFF5468),
        intensity: 0.9,
        animation: ThemeAnimationConfig(basePulseDuration: 3.6, pulseDepth: 0.4, borderTravelSpeed: 1.15)
    )

    static let acid = Theme(
        id: "nexe.acid",
        displayName: "ACID",
        primaryColor: ThemeColor(hex: 0xB6FF3C),
        secondaryColor: ThemeColor(hex: 0x4C7A0E),
        glowColor: ThemeColor(hex: 0xCFFF6E),
        intensity: 0.8,
        animation: ThemeAnimationConfig(basePulseDuration: 4.0, pulseDepth: 0.32, borderTravelSpeed: 1.05)
    )

    static let purpleCore = Theme(
        id: "nexe.purplecore",
        displayName: "PURPLE CORE",
        primaryColor: ThemeColor(hex: 0x9B4DFF),
        secondaryColor: ThemeColor(hex: 0xE23DE0), // magenta
        glowColor: ThemeColor(hex: 0xB479FF),
        intensity: 0.85,
        animation: ThemeAnimationConfig(basePulseDuration: 4.8, pulseDepth: 0.3, borderTravelSpeed: 0.95)
    )

    /// All built-in themes, in the order they should appear in the picker.
    /// Add a new theme here (and only here) to make it available everywhere.
    static let all: [Theme] = [.nexeVoid, .cyberBlue, .signalRed, .acid, .purpleCore]

    static func byID(_ id: String) -> Theme {
        all.first(where: { $0.id == id }) ?? .nexeVoid
    }
}
