//
//  OverlayWindow.swift
//  NEXENeonOverlay
//
//  A borderless, transparent, click-through NSWindow that sits visually on
//  top of the FL Studio window. It never becomes key/main, never receives
//  mouse events, never shows in the Dock or Cmd+Tab, and carries no shadow —
//  every property here exists specifically to make the overlay invisible to
//  everything except the user's eyes.
//

import AppKit

final class OverlayWindow: NSWindow {

    init(initialFrame: CGRect) {
        super.init(
            contentRect: initialFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false

        // Sit above the FL Studio window without becoming a persistent
        // system-wide overlay that fights with other apps' own floating
        // panels; `.floating` is the standard, well-behaved level for a
        // "stay on top of one normal-level app window" companion window.
        level = .floating

        // Present alongside FL Studio on every Space it appears on, never
        // take part in window cycling (Cmd+`), never get its own Mission
        // Control / Exposé slot, and do not participate in the Dock icon's
        // "show all windows" behavior.
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary,
        ]

        // Never take keyboard/mouse focus and never show in Cmd+Tab or the
        // Dock's per-app window list.
        isExcludedFromWindowsMenu = true
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
