//
//  WindowTracker.swift
//  NEXENeonOverlay
//
//  Follows a single external application's frontmost window using the
//  public macOS Accessibility API (AXUIElement / AXObserver). This is the
//  officially supported way for one app to read another app's window frame
//  without touching its process, memory, or files in any way.
//
//  Requires the user to have granted NEXE Accessibility access (see
//  PermissionManager). Until that is granted, AXUIElement calls simply fail
//  gracefully (empty/nil results) — WindowTracker never crashes or retries
//  aggressively when untrusted, it just reports "not available".
//

import AppKit
import ApplicationServices
import Combine

/// A window frame in Cocoa (AppKit) screen coordinates: origin at the
/// bottom-left of the primary display, Y increasing upward — the same
/// space `NSWindow.setFrame(_:display:)` expects.
struct TrackedFrame: Equatable {
    var origin: CGPoint
    var size: CGSize

    var rect: CGRect { CGRect(origin: origin, size: size) }
}

final class WindowTracker: ObservableObject {

    @Published private(set) var frame: TrackedFrame?
    /// True while the tracked window exists, is not miniaturized, and is
    /// not in full screen (full screen is handled as a graceful fallback —
    /// see AppState / OverlayManager).
    @Published private(set) var isWindowVisible: Bool = false
    @Published private(set) var isFullScreen: Bool = false

    private var axApp: AXUIElement?
    private var axWindow: AXUIElement?
    private var observer: AXObserver?
    private let pid: pid_t

    init(pid: pid_t) {
        self.pid = pid
        self.axApp = AXUIElementCreateApplication(pid)
        attachToMainWindow()
    }

    deinit {
        teardownObserver()
    }

    /// Call after Accessibility permission is granted (or on first attempt)
    /// to (re)acquire the app's main window and start observing it.
    func attachToMainWindow() {
        teardownObserver()

        guard AXIsProcessTrusted(), let axApp else {
            frame = nil
            isWindowVisible = false
            return
        }

        guard let window = Self.copyMainWindow(of: axApp) else {
            frame = nil
            isWindowVisible = false
            return
        }

        axWindow = window
        refreshFrame()
        isWindowVisible = true
        setupObserver(for: window)
    }

    // MARK: - Frame reading

    private func refreshFrame() {
        guard let axWindow else { return }

        guard let axPosition = Self.copyAttribute(axWindow, kAXPositionAttribute),
              let axSize = Self.copyAttribute(axWindow, kAXSizeAttribute) else {
            return
        }

        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(axPosition as! AXValue, .cgPoint, &point),
              AXValueGetValue(axSize as! AXValue, .cgSize, &size) else {
            return
        }

        let cocoaOrigin = Self.convertAXPointToCocoa(topLeft: point, size: size)
        let newFrame = TrackedFrame(origin: cocoaOrigin, size: size)

        if newFrame != frame {
            frame = newFrame
        }

        isFullScreen = Self.windowIsFullScreen(axWindow)
    }

    // MARK: - AXObserver (event-driven, no polling of geometry)

    private func setupObserver(for window: AXUIElement) {
        var newObserver: AXObserver?
        let callback: AXObserverCallback = { _, _, notificationName, refcon in
            guard let refcon else { return }
            let tracker = Unmanaged<WindowTracker>.fromOpaque(refcon).takeUnretainedValue()
            DispatchQueue.main.async {
                tracker.handleNotification(notificationName as String)
            }
        }

        guard AXObserverCreate(pid, callback, &newObserver) == .success, let createdObserver = newObserver else {
            return
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let notifications: [CFString] = [
            kAXMovedNotification as CFString,
            kAXResizedNotification as CFString,
            kAXUIElementDestroyedNotification as CFString,
            kAXWindowMiniaturizedNotification as CFString,
            kAXWindowDeminiaturizedNotification as CFString,
        ]

        for notification in notifications {
            AXObserverAddNotification(createdObserver, window, notification, refcon)
        }

        CFRunLoopAddSource(
            RunLoop.current.getCFRunLoop(),
            AXObserverGetRunLoopSource(createdObserver),
            .defaultMode
        )

        observer = createdObserver
    }

    private func teardownObserver() {
        if let observer {
            CFRunLoopRemoveSource(
                RunLoop.current.getCFRunLoop(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
        }
        observer = nil
        axWindow = nil
    }

    private func handleNotification(_ name: String) {
        switch name {
        case kAXUIElementDestroyedNotification:
            frame = nil
            isWindowVisible = false
            teardownObserver()
            // The window (e.g. a document window) was closed; try to
            // reattach to whatever main window remains, if any.
            attachToMainWindow()
        case kAXWindowMiniaturizedNotification:
            isWindowVisible = false
        case kAXWindowDeminiaturizedNotification:
            isWindowVisible = true
            refreshFrame()
        default:
            refreshFrame()
        }
    }

    // MARK: - AX helpers

    private static func copyMainWindow(of app: AXUIElement) -> AXUIElement? {
        if let value = copyAttribute(app, kAXMainWindowAttribute) {
            return (value as! AXUIElement)
        }
        if let value = copyAttribute(app, kAXFocusedWindowAttribute) {
            return (value as! AXUIElement)
        }
        // Fall back to the first entry in the window list.
        if let windowsValue = copyAttribute(app, kAXWindowsAttribute),
           let windows = windowsValue as? [AXUIElement],
           let first = windows.first {
            return first
        }
        return nil
    }

    private static func copyAttribute(_ element: AXUIElement, _ attribute: String) -> AnyObject? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else { return nil }
        return value
    }

    private static func windowIsFullScreen(_ window: AXUIElement) -> Bool {
        // There is no direct public AX attribute for "is full screen".
        // The closest stable, official signal is comparing the window's
        // frame against the screen's frame it is on; if they match (within
        // a small tolerance) we treat it as full screen for the purpose of
        // deciding whether to draw the overlay (see OverlayManager).
        guard let axPosition = copyAttribute(window, kAXPositionAttribute),
              let axSize = copyAttribute(window, kAXSizeAttribute) else {
            return false
        }
        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(axPosition as! AXValue, .cgPoint, &point),
              AXValueGetValue(axSize as! AXValue, .cgSize, &size) else {
            return false
        }
        let cocoaOrigin = convertAXPointToCocoa(topLeft: point, size: size)
        let windowRect = CGRect(origin: cocoaOrigin, size: size)

        for screen in NSScreen.screens {
            if screen.frame.equalTo(windowRect) {
                return true
            }
        }
        return false
    }

    /// The Accessibility API reports window position in "top-left origin,
    /// Y-down" screen coordinates (matching Core Graphics display space),
    /// while AppKit's NSWindow / NSScreen APIs use "bottom-left origin,
    /// Y-up" coordinates. This converts using the primary screen's height,
    /// which is the standard, documented conversion between the two spaces.
    private static func convertAXPointToCocoa(topLeft: CGPoint, size: CGSize) -> CGPoint {
        guard let primaryScreen = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.screens.first else {
            return topLeft
        }
        let flippedY = primaryScreen.frame.height - topLeft.y - size.height
        return CGPoint(x: topLeft.x, y: flippedY)
    }
}
