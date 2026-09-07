//
//  EffectMode.swift
//  NEXENeonOverlay
//
//  Which visual technique NEXE uses to draw the overlay. OUTLINE ONLY traces
//  a single neon frame around FL Studio's outer window edge (cheap, always
//  available, no extra permission). LIVE EDGE GLOW instead reads FL Studio's
//  own on-screen pixels and traces glowing neon lines around every button,
//  panel, and pattern grid line FL Studio itself draws — see
//  WindowCaptureService and EdgeGlowRenderer. It requires Screen Recording
//  permission.
//

import Foundation

enum EffectMode: String, CaseIterable, Identifiable, Codable {
    case outlineOnly
    case liveEdgeGlow

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .outlineOnly: return "OUTLINE ONLY"
        case .liveEdgeGlow: return "LIVE EDGE GLOW"
        }
    }
}
