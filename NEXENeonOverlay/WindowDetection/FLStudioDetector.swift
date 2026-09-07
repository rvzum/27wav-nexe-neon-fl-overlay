//
//  FLStudioDetector.swift
//  NEXENeonOverlay
//
//  Detects a running FL Studio process using only the public
//  NSWorkspace.shared.runningApplications API and NSWorkspace's launch /
//  terminate notifications. No private API, no polling of process lists,
//  no injection: this only ever *observes* already-public information the
//  system already publishes about running applications.
//

import AppKit
import Combine

/// Connection state surfaced to the UI (`SettingsView` status pill).
enum FLStudioConnectionState: Equatable {
    case waiting
    case connected(appName: String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var statusText: String {
        switch self {
        case .waiting: return "WAITING FOR FL STUDIO"
        case .connected(let appName): return appName.uppercased()
        }
    }
}

final class FLStudioDetector: ObservableObject {

    /// Bundle identifier fragments and localized-name fragments that
    /// identify FL Studio / Image-Line's macOS build. Matching on both
    /// keeps detection working across FL Studio versions and localized
    /// display names, without hardcoding one exact bundle identifier that
    /// might change between releases.
    private static let bundleIDFragments = ["image-line", "fl-studio", "flstudio"]
    private static let nameFragments = ["fl studio"]

    @Published private(set) var state: FLStudioConnectionState = .waiting
    @Published private(set) var runningApp: NSRunningApplication?

    private let workspace = NSWorkspace.shared
    private var launchObserver: NSObjectProtocol?
    private var terminateObserver: NSObjectProtocol?

    init() {
        scanForFLStudio()
        subscribeToWorkspaceNotifications()
    }

    deinit {
        if let launchObserver {
            workspace.notificationCenter.removeObserver(launchObserver)
        }
        if let terminateObserver {
            workspace.notificationCenter.removeObserver(terminateObserver)
        }
    }

    /// Event-driven, not polling: NSWorkspace posts these notifications
    /// whenever any application launches or terminates, so NEXE only does
    /// work at the exact moments FL Studio's process state could have
    /// changed instead of repeatedly scanning in a timer loop.
    private func subscribeToWorkspaceNotifications() {
        launchObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleLaunch(notification)
        }

        terminateObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleTermination(notification)
        }
    }

    private func handleLaunch(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        if Self.matches(app) {
            connect(to: app)
        }
    }

    private func handleTermination(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        if app.processIdentifier == runningApp?.processIdentifier {
            disconnect()
        }
    }

    /// Initial scan performed once at launch (covers the case where FL
    /// Studio was already running before NEXE started).
    private func scanForFLStudio() {
        if let app = workspace.runningApplications.first(where: Self.matches) {
            connect(to: app)
        } else {
            state = .waiting
            runningApp = nil
        }
    }

    private func connect(to app: NSRunningApplication) {
        runningApp = app
        let displayName = app.localizedName ?? "FL Studio"
        state = .connected(appName: displayName)
    }

    private func disconnect() {
        runningApp = nil
        state = .waiting
    }

    private static func matches(_ app: NSRunningApplication) -> Bool {
        if let bundleID = app.bundleIdentifier?.lowercased() {
            if bundleIDFragments.contains(where: { bundleID.contains($0) }) {
                return true
            }
        }
        if let name = app.localizedName?.lowercased() {
            if nameFragments.contains(where: { name.contains($0) }) {
                return true
            }
        }
        return false
    }
}
