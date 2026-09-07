//
//  NEXENeonOverlayApp.swift
//  NEXENeonOverlay
//
//  App entry point. NEXE runs as an accessory (menu-bar) app: no Dock icon,
//  no regular app window other than the NEXE Visual Engine settings panel
//  the user opens deliberately from the menu bar. This keeps the overlay
//  window itself the *only* thing ever drawn on top of FL Studio.
//

import SwiftUI
import AppKit

@main
struct NEXENeonOverlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // The real UI is a manually managed NSWindow (see AppDelegate) so it
        // can be styled edge-to-edge and shown from the status item without
        // SwiftUI's default window chrome. This Settings scene intentionally
        // has no visible content and exists only so the app has a valid
        // SwiftUI Scene graph.
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appState: AppState!
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Accessory: no Dock icon, no app menu bar at the top of the
        // screen — matches the "overlay app that lives in the menu bar"
        // pattern and keeps NEXE out of the Dock as required.
        NSApp.setActivationPolicy(.accessory)

        appState = AppState()
        setupStatusItem()
        showSettingsWindow()
    }

    // MARK: - Status item (menu bar)

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "hexagon.fill", accessibilityDescription: "NEXE")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open NEXE Panel…", action: #selector(openSettings), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let toggleItem = NSMenuItem(title: "Toggle Overlay", action: #selector(toggleOverlay), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit NEXE", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    @objc private func toggleOverlay() {
        appState.settings.isOverlayEnabled.toggle()
    }

    @objc private func openSettings() {
        showSettingsWindow()
    }

    // MARK: - Settings window

    private func showSettingsWindow() {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(rootView: SettingsView().environmentObject(appState))
        let window = NSWindow(contentViewController: hosting)
        window.title = "NEXE — Visual Engine"
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.center()

        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
