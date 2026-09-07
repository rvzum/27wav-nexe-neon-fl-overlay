//
//  ToggleRow.swift
//  NEXENeonOverlay
//
//  A settings-panel toggle row (ENABLE VISUAL OVERLAY, PARTICLES, ...).
//

import SwiftUI

struct ToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    var accent: Color = .white

    init(title: String, subtitle: String? = nil, isOn: Binding<Bool>, accent: Color = .white) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
        self.accent = accent
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                    .tracking(0.6)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(accent)
        }
    }
}
