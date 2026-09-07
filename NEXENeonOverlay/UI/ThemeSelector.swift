//
//  ThemeSelector.swift
//  NEXENeonOverlay
//
//  Theme picker: a swatch + name for every entry in `Theme.all`. Adding a
//  new theme to that array is all that's needed for it to show up here.
//

import SwiftUI

struct ThemeSelector: View {
    @Binding var selection: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("THEME")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
                .tracking(1.1)

            VStack(spacing: 6) {
                ForEach(Theme.all) { theme in
                    themeRow(theme)
                }
            }
        }
    }

    private func themeRow(_ theme: Theme) -> some View {
        let isSelected = theme.id == selection.id
        return Button {
            selection = theme
        } label: {
            HStack(spacing: 10) {
                swatch(theme)
                Text(theme.displayName)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                    .tracking(0.8)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(theme.primaryColor.color)
                        .font(.system(size: 13))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.06) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isSelected ? theme.primaryColor.color.opacity(0.5) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func swatch(_ theme: Theme) -> some View {
        ZStack {
            Circle()
                .fill(theme.primaryColor.color)
                .frame(width: 16, height: 16)
            Circle()
                .fill(theme.secondaryColor.color)
                .frame(width: 8, height: 8)
                .offset(x: 5, y: 5)
        }
        .shadow(color: theme.glowColor.color.opacity(0.6), radius: 4)
    }
}
