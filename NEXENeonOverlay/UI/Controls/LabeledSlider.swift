//
//  LabeledSlider.swift
//  NEXENeonOverlay
//
//  A settings-panel slider row: uppercase monospaced label, live numeric
//  readout, and an accent-colored track matching the active theme.
//

import SwiftUI
import Foundation

struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var accent: Color = .white
    var valueFormatter: (Double) -> String = { String(format: "%.0f", $0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(1.1)
                Spacer()
                Text(valueFormatter(value))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(accent)
            }
            Slider(value: $value, in: range)
                .tint(accent)
        }
    }
}
