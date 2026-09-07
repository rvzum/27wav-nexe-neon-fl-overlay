//
//  OverlayManager.swift
//  NEXENeonOverlay
//
//  The conductor: wires FLStudioDetector + WindowTracker + PermissionManager
//  + OverlaySettings together and owns the single OverlayWindow instance's
//  lifecycle. This is the only place that creates/destroys/repositions the
//  overlay window.
//

import AppKit
import SwiftUI
import Combine

final class OverlayManager: ObservableObject {

    private let detector: FLStudioDetector
    private let permissions: PermissionManager
    private let settings: OverlaySettings

    private var window: OverlayWindow?
    private var hostingController: NSHostingController<OverlayView>?
    private var windowTracker: WindowTracker?

    private var cancellables = Set<AnyCancellable>()

    /// Surfaced to the UI so SettingsView can show a small explanatory note
    /// when the overlay is intentionally hidden during full screen.
    @Published private(set) var isSuspendedForFullScreen: Bool = false

    init(detector: FLStudioDetector, permissions: PermissionManager, settings: OverlaySettings) {
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
                // Permission was just granted — (re)acquire the AX window.
                self.startTracking(pid: app.processIdentifier)
            }
            .store(in: &cancellables)
    }

    // MARK: - Tracking lifecycle

    private func startTracking(pid: pid_t) {
        let tracker = WindowTracker(pid: pid)
        windowTracker = tracker

        tracker.$frame
            .receive(on: DispatchQueue.main)
            .sink { [weak self] frame in
                self?.handleFrameUpdate(frame)
            }
            .store(in: &cancellables)

        tracker.$isFullScreen
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isFullScreen in
                self?.isSuspendedForFullScreen = isFullScreen
                self?.refreshVisibility()
            }
            .store(in: &cancellables)

        tracker.$isWindowVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshVisibility() }
            .store(in: &cancellables)
    }

    private func stopTracking() {
        windowTracker = nil
        destroyWindow()
    }

    private func handleFrameUpdate(_ frame: TrackedFrame?) {
        guard let frame else {
            destroyWindow()
            return
        }

        if let window {
            window.setFrame(frame.rect, display: true)
        } else {
            createWindow(frame: frame.rect)
        }
        refreshVisibility()
    }

    // MARK: - Window management

    private func createWindow(frame: CGRect) {
        let overlayWindow = OverlayWindow(initialFrame: frame)
        let view = OverlayView(settings: settings)
        let controller = NSHostingController(rootView: view)
        controller.view.frame = CGRect(origin: .zero, size: frame.size)
        overlayWindow.contentView = controller.view

        window = overlayWindow
        hostingController = controller
        refreshVisibility()
    }

    private func destroyWindow() {
        window?.orderOut(nil)
        window = nil
        hostingController = nil
    }

    /// Central visibility rule: the overlay only shows when FL Studio is
    /// running, its window is on-screen (not miniaturized), it is not in
    /// full screen (see WindowTracker's full-screen fallback note), and the
    /// user has the overlay enabled in Settings.
    private func refreshVisibility() {
        guard let window else { return }

        let shouldShow = settings.isOverlayEnabled
            && detector.state.isConnected
            && (windowTracker?.isWindowVisible ?? false)
            && !(windowTracker?.isFullScreen ?? false)

        if shouldShow {
            if !window.isVisible {
                window.orderFront(nil)
            }
        } else {
            if window.isVisible {
                window.orderOut(nil)
            }
        }
    }
}
