//
//  OverlayManager.swift
//  NEXENeonOverlay
//
//  The conductor: wires FLStudioDetector + WindowTracker + PermissionManager
//  + OverlaySettings together and owns the lifecycle of one OverlayWindow
//  per FL Studio window currently on screen. This is the only place that
//  creates/destroys/repositions overlay windows — every real FL Studio
//  window (main window, Playlist, Piano Roll, Mixer, Channel Rack, Browser,
//  any other undocked panel) gets its own independent neon border,
//  positioned and animated entirely from AXUIElement window geometry. No
//  screen or pixel content is ever read.
//

import AppKit
import SwiftUI
import Combine

final class OverlayManager: ObservableObject {

    private let detector: FLStudioDetector
    private let permissions: PermissionManager
    private let settings: OverlaySettings

    private var windowTracker: WindowTracker?
    private var overlayWindows: [AXWindowID: OverlayWindowController] = [:]

    private var cancellables = Set<AnyCancellable>()
    private var trackerCancellables = Set<AnyCancellable>()

    /// How many FL Studio windows currently have a neon border — surfaced
    /// to the UI as a small live status line.
    @Published private(set) var trackedWindowCount: Int = 0

    /// Surfaced to the UI so SettingsView can show a small explanatory note
    /// when every currently-open FL Studio window happens to be full
    /// screen (so nothing is visibly outlined right now).
    @Published private(set) var isSuspendedForFullScreen: Bool = false

    init(
        detector: FLStudioDetector,
        permissions: PermissionManager,
        settings: OverlaySettings
    ) {
        self.detector = detector
        self.permissions = permissions
        self.settings = settings

        observeDetector()
        observeSettings()
        observePermissions()
    }

    // MARK: - Observation

    private func observeDetector() {
        detector.$runningApp
            .receive(on: DispatchQueue.main)
            .sink { [weak self] app in
                guard let self else { return }
                if let app {
                    self.startTracking(pid: app.processIdentifier)
                } else {
                    self.stopTracking()
                }
            }
            .store(in: &cancellables)
    }

    private func observeSettings() {
        settings.$isOverlayEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshVisibility() }
            .store(in: &cancellables)
    }

    private func observePermissions() {
        permissions.$isTrusted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] trusted in
                guard trusted, let self, let app = self.detector.runningApp else { return }
                // Permission was just granted — (re)acquire every AX window.
                self.startTracking(pid: app.processIdentifier)
            }
            .store(in: &cancellables)
    }

    // MARK: - Tracking lifecycle

    private func startTracking(pid: pid_t) {
        trackerCancellables.removeAll()

        let tracker = WindowTracker(pid: pid)
        windowTracker = tracker

        tracker.$windows
            .receive(on: DispatchQueue.main)
            .sink { [weak self] windows in
                self?.reconcile(windows)
            }
            .store(in: &trackerCancellables)
    }

    private func stopTracking() {
        trackerCancellables.removeAll()
        windowTracker = nil
        reconcile([:])
    }

    /// Creates, updates, or destroys one overlay window per tracked FL
    /// Studio window so every real window independently gets its own live
    /// neon border, moving and resizing with it.
    private func reconcile(_ windows: [AXWindowID: TrackedWindow]) {
        for id in overlayWindows.keys where windows[id] == nil {
            overlayWindows[id]?.destroy()
            overlayWindows.removeValue(forKey: id)
        }

        for (id, tracked) in windows {
            if let controller = overlayWindows[id] {
                controller.update(frame: tracked.frame.rect)
            } else {
                overlayWindows[id] = OverlayWindowController(initialFrame: tracked.frame.rect, settings: settings)
            }
        }

        trackedWindowCount = windows.values.filter { !$0.isFullScreen }.count
        isSuspendedForFullScreen = !windows.isEmpty && windows.values.allSatisfy { $0.isFullScreen }

        applyVisibility(windows)
    }

    /// Re-applies the visibility rule using whatever `WindowTracker` last
    /// reported. Only safe to call from contexts that are *not* already
    /// reacting to a fresh `$windows` emission — see `reconcile(_:)`, which
    /// passes that emission's value straight to `applyVisibility(_:)`
    /// instead, since `@Published` delivers its new value slightly ahead of
    /// actually storing it on the object, so re-reading `windowTracker.windows`
    /// from inside that same emission's handler could still observe the
    /// previous state.
    private func refreshVisibility() {
        applyVisibility(windowTracker?.windows ?? [:])
    }

    /// Central visibility rule: each overlay window only shows when FL
    /// Studio is running, the user has the overlay enabled in Settings, and
    /// that particular FL Studio window isn't full screen (see
    /// WindowTracker's full-screen fallback note) — every other tracked
    /// window keeps showing its own border independently.
    private func applyVisibility(_ windows: [AXWindowID: TrackedWindow]) {
        let baseShouldShow = settings.isOverlayEnabled && detector.state.isConnected

        for (id, controller) in overlayWindows {
            let isFullScreen = windows[id]?.isFullScreen ?? false
            if baseShouldShow && !isFullScreen {
                controller.show()
            } else {
                controller.hide()
            }
        }
    }
}

/// Owns one OverlayWindow and its hosted SwiftUI content for exactly one
/// tracked FL Studio window. Kept private to OverlayManager — nothing else
/// needs to know an overlay window controller exists.
private final class OverlayWindowController {
    private let window: OverlayWindow
    private let hostingController: NSHostingController<OverlayView>

    init(initialFrame: CGRect, settings: OverlaySettings) {
        let overlayWindow = OverlayWindow(initialFrame: initialFrame)
        let controller = NSHostingController(rootView: OverlayView(settings: settings))
        controller.view.frame = CGRect(origin: .zero, size: initialFrame.size)
        overlayWindow.contentView = controller.view

        self.window = overlayWindow
        self.hostingController = controller
    }

    func update(frame: CGRect) {
        window.setFrame(frame, display: true)
    }

    func show() {
        if !window.isVisible {
            window.orderFront(nil)
        }
    }

    func hide() {
        if window.isVisible {
            window.orderOut(nil)
        }
    }

    func destroy() {
        window.orderOut(nil)
    }
}
