//
//  StatusBadge.swift
//  NEXENeonOverlay
//
//  The FL STUDIO ● CONNECTED / ● WAITING FOR FL STUDIO status pill shown at
//  the top of the settings window.
//

import SwiftUI

struct StatusBadge: View {
    let state: FLStudioConnectionState

    var body: some View {
        HStack(spacing: 10) {
            Text("FL STUDIO")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.55))
                .tracking(1.2)

            HStack(spacing: 6) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 7, height: 7)
                    .shadow(color: dotColor.opacity(0.9), radius: state.isConnected ? 5 : 0)

                Text(state.statusText)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(dotColor)
                    .tracking(1.0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var dotColor: Color {
        state.isConnected ? Color(red: 0.35, green: 0.95, blue: 0.55) : Color(red: 0.95, green: 0.65, blue: 0.25)
    }
}
