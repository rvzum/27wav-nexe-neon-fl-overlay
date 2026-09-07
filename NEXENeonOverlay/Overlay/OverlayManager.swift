//
//  OverlayManager.swift
//  NEXENeonOverlay
//
//  The conductor: wires FLStudioDetector + WindowTracker + PermissionManager
//  + OverlaySettings together and owns the single OverlayWindow instance's
//  lifecycle. This is the only place that creates/destroys/repositions the
//  overlay window. It also owns the LIVE EDGE GLOW capture pipeline
//  (WindowCaptureService + EdgeGlowController), starting/stopping it only
//  when that effect mode is selected and Screen Recording access is
//  granted, so OUTLINE ONLY mode costs nothing extra.
//

import AppKit
import SwiftUI
import Combine

final class OverlayManager: ObservableObject {

    private let detector: FLStudioDetector
    private let permissions: PermissionManager
    private let settings: OverlaySettings
    private let screenCapturePermission: ScreenCapturePermission

    private var window: OverlayWindow?
    private var hostingController: NSHostingController<OverlayView>?
    private var windowTracker: WindowTracker?

    private let captureService = WindowCaptureService()
    private lazy var edgeGlowController = EdgeGlowController(capture: captureService, settings: settings)
    private var lastCaptureSize: CGSize?

    private var cancellables = Set<AnyCancellable>()

    /// Surfaced to the UI so SettingsView can show a small explanatory note
    /// when the overlay is intentionally hidden during full screen.
    @Published private(set) var isSuspendedForFullScreen: Bool = false

    init(
        detector: FLStudioDetector,
        permissions: PermissionManager,
        settings: OverlaySettings,
        screenCapturePermission: ScreenCapturePermission
    ) {
        self.detector = detector
        self.permissions = permissions
        self.settings = settings
        self.screenCapturePermission = screenCapturePermission

        observeDetector()
        observeSettings()
        observePermissions()
        observeCaptureConditions()
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

    /// LIVE EDGE GLOW's capture stream only runs while that mode is selected
    /// and Screen Recording access has been granted; it stays fully off
    /// otherwise so OUTLINE ONLY mode costs nothing extra.
    private func observeCaptureConditions() {
        Publishers.CombineLatest(settings.$effectMode, screenCapturePermission.$isGranted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode, granted in
                guard let self else { return }
                print("[NEXE] OverlayManager: effect mode = \(mode), screen recording granted = \(granted), FL Studio pid = \(self.detector.runningApp?.processIdentifier.description ?? "nil")")
                if mode == .liveEdgeGlow, granted, let app = self.detector.runningApp {
                    self.captureService.start(pid: app.processIdentifier)
                } else {
                    self.captureService.stop()
                    self.lastCaptureSize = nil
                }
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
        captureService.stop()
        lastCaptureSize = nil
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

        updateCaptureIfNeeded(newSize: frame.size)
        refreshVisibility()
    }

    /// (Re)starts the LIVE EDGE GLOW capture stream when FL Studio's window
    /// is resized, since a ScreenCaptureKit stream's configuration is fixed
    /// at creation time. A small tolerance avoids restarting on sub-pixel
    /// jitter from ordinary window moves.
    private func updateCaptureIfNeeded(newSize: CGSize) {
        guard settings.effectMode == .liveEdgeGlow,
              screenCapturePermission.isGranted,
              let app = detector.runningApp else { return }

        if let last = lastCaptureSize {
            if abs(last.width - newSize.width) > 4 || abs(last.height - newSize.height) > 4 {
                captureService.restart(pid: app.processIdentifier)
                lastCaptureSize = newSize
            }
        } else {
            captureService.start(pid: app.processIdentifier)
            lastCaptureSize = newSize
        }
    }

    // MARK: - Window management

    private func createWindow(frame: CGRect) {
        let overlayWindow = OverlayWindow(initialFrame: frame)
        let view = OverlayView(settings: settings, edgeGlow: edgeGlowController)
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
