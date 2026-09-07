//
//  ScreenCapturePermission.swift
//  NEXENeonOverlay
//
//  Wraps the public Screen Recording permission APIs
//  (CGPreflightScreenCaptureAccess / CGRequestScreenCaptureAccess). LIVE EDGE
//  GLOW mode captures FL Studio's own window content (via ScreenCaptureKit)
//  purely to read pixels already on screen — the same thing a screenshot
//  does — so it can trace neon edges around every button, panel, and
//  pattern grid line FL Studio actually draws. This never reads FL Studio's
//  memory, files, or internal state; it only sees what is already visible on
//  screen, through the same Screen Recording permission every screenshot or
//  screen-recording utility uses.
//
//  Like Accessibility, macOS exposes no change notification for this
//  permission, so this class polls at a low frequency, matching
//  PermissionManager's pattern. Unlike Accessibility, a freshly granted
//  Screen Recording permission typically only takes effect for a process
//  after that process relaunches — the Settings UI says so explicitly.
//

import Foundation
import CoreGraphics
import AppKit
import Combine

final class ScreenCapturePermission: ObservableObject {

    static let explanation =
        "LIVE EDGE GLOW reads FL Studio's on-screen pixels (like a screenshot) to trace neon outlines around every button, panel, and pattern grid line. This requires Screen Recording permission."

    @Published private(set) var isGranted: Bool = CGPreflightScreenCaptureAccess()

    private var pollTimer: Timer?

    init() {
        startPolling()
    }

    deinit {
        pollTimer?.invalidate()
    }

    /// Prompts the system's own Screen Recording consent dialog the first
    /// time; afterwards this just re-checks the current state, mirroring
    /// PermissionManager.requestAccess()'s behavior for Accessibility.
    func requestAccess() {
        let granted = CGRequestScreenCaptureAccess()
        isGranted = granted
        if !granted {
            openScreenRecordingSettings()
        }
    }

    func openScreenRecordingSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private func startPolling() {
        pollTimer?.invalidate()
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let granted = CGPreflightScreenCaptureAccess()
            if granted != self.isGranted {
                DispatchQueue.main.async {
                    self.isGranted = granted
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }
}
