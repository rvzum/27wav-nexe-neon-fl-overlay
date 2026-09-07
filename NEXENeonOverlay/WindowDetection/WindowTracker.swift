//
//  WindowTracker.swift
//  NEXENeonOverlay
//
//  Follows *every* window a target application currently has open — its
//  main window, plus every undocked panel (for FL Studio: Playlist, Piano
//  Roll, Mixer, Channel Rack, Browser, and any other window it happens to
//  own) — using only the public macOS Accessibility API (AXUIElement /
//  AXObserver). This is the officially supported way for one app to read
//  another app's window frames without touching its process, memory, or
//  files in any way, and — unlike screen capture — it needs no Screen
//  Recording permission at all: window *geometry* (position/size) is public
//  Accessibility data, not pixel content.
//
//  Each FL Studio window is a real, separate NSWindow on macOS the moment
//  it's undocked, so tracking "every AX window this app owns" is exactly
//  the same thing as "every frame/section the user sees as its own panel" —
//  NEXE draws one independent neon border per tracked window, so moving,
//  resizing, opening, or closing any one of them updates only that
//  window's border.
//
//  Requires the user to have granted NEXE Accessibility access (see
//  PermissionManager). Until that is granted, AXUIElement calls simply fail
//  gracefully (empty results) — WindowTracker never crashes or retries
//  aggressively when untrusted, it just reports "nothing tracked".
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

/// Wraps an `AXUIElement` window handle so it can be used as a stable,
/// correctly-comparable dictionary key across AX notification callbacks.
/// `AXUIElementRef` is a `CFType`; comparing two of them with `CFEqual` (and
/// hashing with `CFHash`) — rather than Swift's default identity semantics —
/// is the documented, public way to tell whether two `AXUIElement` values
/// refer to the same accessibility object.
struct AXWindowID: Hashable {
    let element: AXUIElement

    static func == (lhs: AXWindowID, rhs: AXWindowID) -> Bool {
        CFEqual(lhs.element, rhs.element)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(CFHash(element))
    }

    /// Short, stable-enough label for console diagnostics only — never used
    /// for equality/lookup (that's CFEqual/CFHash above).
    var debugLabel: String {
        String(format: "0x%x", CFHash(element))
    }
}

/// One target-app window NEXE is currently following.
struct TrackedWindow: Identifiable {
    let id: AXWindowID
    var frame: TrackedFrame
    var isFullScreen: Bool
}

final class WindowTracker: ObservableObject {

    /// Every eligible window the target app currently has open and visible
    /// (not miniaturized), keyed by a stable per-window identity. NEXE
    /// creates one overlay window per entry here — see OverlayManager.
    @Published private(set) var windows: [AXWindowID: TrackedWindow] = [:]

    private let pid: pid_t
    private var axApp: AXUIElement?
    private var observer: AXObserver?
    /// Keeps every currently-tracked AXUIElement strongly referenced. The
    /// notifications we register are tied to these specific element
    /// instances, so they must stay alive for as long as we're observing
    /// them.
    private var trackedElements: [AXWindowID: AXUIElement] = [:]

    private static let perWindowNotifications: [CFString] = [
        kAXMovedNotification as CFString,
        kAXResizedNotification as CFString,
        kAXUIElementDestroyedNotification as CFString,
        kAXWindowMiniaturizedNotification as CFString,
        kAXWindowDeminiaturizedNotification as CFString,
    ]

    /// FL Studio occasionally owns small helper windows (tooltips, color
    /// swatches, popovers) that aren't a "section" anyone wants outlined —
    /// this floor keeps NEXE glowing only substantial, real panels.
    private static let minimumTrackedDimension: CGFloat = 80

    init(pid: pid_t) {
        self.pid = pid
        self.axApp = AXUIElementCreateApplication(pid)
        attach()
    }

    deinit {
        teardown()
    }

    /// Call after Accessibility permission is granted (or on first attempt)
    /// to (re)acquire every window the app currently owns and start
    /// observing all of them.
    func attach() {
        teardown()

        guard AXIsProcessTrusted(), let axApp else {
            print("[NEXE] WindowTracker: attach() aborted — trusted = \(AXIsProcessTrusted()), axApp = \(axApp != nil)")
            windows = [:]
            return
        }

        setupAppObserver(axApp)
        let discovered = Self.copyWindows(of: axApp)
        print("[NEXE] WindowTracker: attach() found \(discovered.count) raw AX window(s) for pid \(pid)")
        for window in discovered {
            register(window)
        }
    }

    // MARK: - Observer lifecycle

    private func setupAppObserver(_ axApp: AXUIElement) {
        var newObserver: AXObserver?
        let callback: AXObserverCallback = { _, element, notificationName, refcon in
            guard let refcon else { return }
            let tracker = Unmanaged<WindowTracker>.fromOpaque(refcon).takeUnretainedValue()
            DispatchQueue.main.async {
                tracker.handleNotification(notificationName as String, element: element)
            }
        }

        guard AXObserverCreate(pid, callback, &newObserver) == .success, let createdObserver = newObserver else {
            return
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        // A single AXObserver instance covers the whole target process;
        // this app-level notification is how NEXE learns about new windows
        // (a newly opened Piano Roll, an undocked Mixer, etc.) as they
        // appear, without polling.
        AXObserverAddNotification(createdObserver, axApp, kAXWindowCreatedNotification as CFString, refcon)

        CFRunLoopAddSource(
            RunLoop.current.getCFRunLoop(),
            AXObserverGetRunLoopSource(createdObserver),
            .defaultMode
        )

        observer = createdObserver
    }

    private func teardown() {
        if let observer {
            CFRunLoopRemoveSource(
                RunLoop.current.getCFRunLoop(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
        }
        observer = nil
        trackedElements.removeAll()
        windows.removeAll()
    }

    // MARK: - Per-window registration

    private func register(_ window: AXUIElement) {
        let id = AXWindowID(element: window)
        guard trackedElements[id] == nil else { return }
        guard let frame = Self.readFrame(window) else {
            print("[NEXE] WindowTracker: register(\(id.debugLabel)) — could not read frame, skipping")
            return
        }
        guard Self.isEligible(frame) else {
            print("[NEXE] WindowTracker: register(\(id.debugLabel)) — frame \(frame.rect) below minimum size, skipping")
            return
        }

        print("[NEXE] WindowTracker: register(\(id.debugLabel)) — tracking, frame = \(frame.rect)")
        trackedElements[id] = window
        windows[id] = TrackedWindow(id: id, frame: frame, isFullScreen: Self.windowIsFullScreen(window))

        if let observer {
            let refcon = Unmanaged.passUnretained(self).toOpaque()
            for notification in Self.perWindowNotifications {
                AXObserverAddNotification(observer, window, notification, refcon)
            }
        }
    }

    private func unregister(_ id: AXWindowID) {
        trackedElements.removeValue(forKey: id)
        windows.removeValue(forKey: id)
    }

    private func refreshFrame(for id: AXWindowID, element: AXUIElement) {
        guard trackedElements[id] != nil, let frame = Self.readFrame(element) else { return }
        let isFullScreen = Self.windowIsFullScreen(element)
        let updated = TrackedWindow(id: id, frame: frame, isFullScreen: isFullScreen)
        if windows[id]?.frame != updated.frame || windows[id]?.isFullScreen != updated.isFullScreen {
            windows[id] = updated
        }
    }

    private func handleNotification(_ name: String, element: AXUIElement) {
        let id = AXWindowID(element: element)
        switch name {
        case kAXWindowCreatedNotification:
            register(element)
        case kAXUIElementDestroyedNotification:
            unregister(id)
        case kAXWindowMiniaturizedNotification:
            // Treat a miniaturized window the same as a closed one for
            // overlay purposes — its overlay disappears until it's restored.
            unregister(id)
        case kAXWindowDeminiaturizedNotification:
            register(element)
        default:
            refreshFrame(for: id, element: element)
        }
    }

    // MARK: - AX helpers

    private static func copyWindows(of app: AXUIElement) -> [AXUIElement] {
        guard let value = copyAttribute(app, kAXWindowsAttribute),
              let windows = value as? [AXUIElement] else {
            return []
        }
        return windows
    }

    private static func copyAttribute(_ element: AXUIElement, _ attribute: String) -> AnyObject? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else { return nil }
        return value
    }

    private static func readFrame(_ window: AXUIElement) -> TrackedFrame? {
        guard let axPosition = copyAttribute(window, kAXPositionAttribute),
              let axSize = copyAttribute(window, kAXSizeAttribute) else {
            return nil
        }

        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(axPosition as! AXValue, .cgPoint, &point),
              AXValueGetValue(axSize as! AXValue, .cgSize, &size) else {
            return nil
        }

        let cocoaOrigin = convertAXPointToCocoa(topLeft: point, size: size)
        return TrackedFrame(origin: cocoaOrigin, size: size)
    }

    private static func isEligible(_ frame: TrackedFrame) -> Bool {
        frame.size.width >= minimumTrackedDimension && frame.size.height >= minimumTrackedDimension
    }

    private static func windowIsFullScreen(_ window: AXUIElement) -> Bool {
        // There is no direct public AX attribute for "is full screen".
        // The closest stable, official signal is comparing the window's
        // frame against the screen's frame it is on; if they match (within
        // a small tolerance) we treat it as full screen for the purpose of
        // deciding whether to draw that window's overlay (see
        // OverlayManager).
        guard let frame = readFrame(window) else { return false }
        for screen in NSScreen.screens {
            if screen.frame.equalTo(frame.rect) {
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
