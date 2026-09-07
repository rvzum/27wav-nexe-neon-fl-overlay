//
//  SettingsView.swift
//  NEXENeonOverlay
//
//  "NEXE — VISUAL ENGINE": the control window. Dark graphite background,
//  restrained neon accents tied to the active theme, monospaced HUD-style
//  labels. Deliberately quiet outside of the accent color — the goal is
//  "premium instrument panel," not "bright cyberpunk poster."
//

import SwiftUI
import Foundation

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    private var accent: Color { appState.settings.theme.primaryColor.color }

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(alignment: .leading, spacing: 22) {
                header

                StatusBadge(state: appState.detector.state)

                if !appState.permissions.isTrusted {
                    accessibilityNotice
                }

                if appState.overlayManager.isSuspendedForFullScreen {
                    fullScreenNotice
                }

                Divider().overlay(Color.white.opacity(0.08))

                ToggleRow(
                    title: "ENABLE VISUAL OVERLAY",
                    subtitle: "Draws the neon frame over FL Studio's window",
                    isOn: $appState.settings.isOverlayEnabled,
                    accent: accent
                )

                ThemeSelector(selection: $appState.settings.theme)

                LabeledSlider(
                    title: "GLOW INTENSITY",
                    value: $appState.settings.glowIntensity,
                    range: 0...100,
                    accent: accent
                )

                LabeledSlider(
                    title: "ANIMATION SPEED",
                    value: $appState.settings.animationSpeed,
                    range: 0...100,
                    accent: accent
                )

                LabeledSlider(
                    title: "FRAME THICKNESS",
                    value: $appState.settings.frameThickness,
                    range: 1...10,
                    accent: accent,
                    valueFormatter: { String(format: "%.1f px", $0) }
                )

                ToggleRow(
                    title: "PARTICLES",
                    subtitle: "Minimal ambient particles (off by default)",
                    isOn: $appState.settings.particlesEnabled,
                    accent: accent
                )

                Spacer(minLength: 0)

                footer
            }
            .padding(24)
        }
        .frame(width: 360, height: 640)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("NEXE")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .tracking(2)
            Text("VISUAL ENGINE")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(accent.opacity(0.85))
                .tracking(3)
        }
    }

    private var accessibilityNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(PermissionManager.explanation)
                .font(.system(size: 11.5))
                .foregroundColor(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)

            Button("Grant Accessibility Access") {
                appState.permissions.requestAccess()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundColor(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(accent)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(accent.opacity(0.35), lineWidth: 1)
        )
    }

    private var fullScreenNotice: some View {
        Text("FL Studio is in full screen — overlay is paused until it returns to a window.")
            .font(.system(size: 10.5))
            .foregroundColor(.white.opacity(0.45))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var footer: some View {
        Text("NEXE never modifies FL Studio. Overlay only.")
            .font(.system(size: 9.5, design: .monospaced))
            .foregroundColor(.white.opacity(0.25))
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.06),
                Color(red: 0.03, green: 0.03, blue: 0.035),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(
            RadialGradient(
                colors: [accent.opacity(0.10), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 420
            )
        )
        .ignoresSafeArea()
    }
}
