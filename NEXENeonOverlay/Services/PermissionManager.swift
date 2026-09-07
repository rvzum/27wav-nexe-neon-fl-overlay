//
//  PermissionManager.swift
//  NEXENeonOverlay
//
//  Wraps the official Accessibility permission APIs (ApplicationServices /
//  AXIsProcessTrusted). NEXE needs this permission to read the position and
//  size of the FL Studio window through the public Accessibility API
//  (AXUIElement) — it is the only supported, non-private way for one macOS
//  app to observe another app's window geometry.
//
//  IMPORTANT: macOS does not expose a system notification that fires when
//  Accessibility trust changes, and there is no Info.plist "usage
//  description" key for it (unlike Camera/Microphone). The officially
//  sanctioned pattern — used throughout the accessibility-tool ecosystem —
//  is to explain *why* you need it in your own UI, call
//  AXIsProcessTrustedWithOptions(...) to let the user grant it from System
//  Settings, and poll AXIsProcessTrusted() at a low frequency until it
//  flips to true. That is what this class does; no private API is used.
//

import Foundation
import ApplicationServices
import AppKit
import Combine

final class PermissionManager: ObservableObject {

    /// Human-readable explanation shown in the UI before requesting access.
    static let explanation =
        "Accessibility permission is required to detect and follow the FL Studio window."

    @Published private(set) var isTrusted: Bool = AXIsProcessTrusted()

    private var pollTimer: Timer?

    init() {
        startPolling()
    }

    deinit {
        pollTimer?.invalidate()
    }

    /// Prompts the user via the system's own "grant Accessibility access"
    /// dialog / directs them to System Settings. Safe to call repeatedly.
    func requestAccess() {
        let options: [String: Any] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let granted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        isTrusted = granted
        if !granted {
            // AXIsProcessTrustedWithOptions with the prompt option already
            // triggers the system dialog on first call. If the user
            // dismissed it previously, fall back to opening the relevant
            // System Settings pane directly using the public URL scheme.
            openAccessibilitySettings()
        }
    }

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    /// Cheap, low-frequency poll (well under the CPU budget) that keeps the
    /// published `isTrusted` value in sync with the real OS state, so the
    /// Settings UI can update automatically the moment the user grants
    /// access in System Settings without requiring an app relaunch.
    private func startPolling() {
        pollTimer?.invalidate()
        let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            let trusted = AXIsProcessTrusted()
            if trusted != self.isTrusted {
                DispatchQueue.main.async {
                    self.isTrusted = trusted
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }
}
