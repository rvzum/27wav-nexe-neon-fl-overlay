//
//  AppState.swift
//  NEXENeonOverlay
//
//  Top-level composition root. One instance lives for the app's lifetime
//  and is handed to SwiftUI via `.environmentObject`.
//

import Foundation
import Combine

final class AppState: ObservableObject {
    // `var`, not `let`: SwiftUI's `$appState.settings.someField` bindings
    // (used throughout SettingsView) need a *writable* key path all the
    // way through, and Swift only synthesizes that when every segment —
    // including this one — is a `var`. The instance itself is still only
    // ever assigned once, in `init`.
    var settings: OverlaySettings
    let detector: FLStudioDetector
    let permissions: PermissionManager
    let overlayManager: OverlayManager

    private var cancellables = Set<AnyCancellable>()

    init() {
        let settings = OverlaySettings()
        let detector = FLStudioDetector()
        let permissions = PermissionManager()

        self.settings = settings
        self.detector = detector
        self.permissions = permissions
        self.overlayManager = OverlayManager(
            detector: detector,
            permissions: permissions,
            settings: settings
        )

        // `settings`, `detector`, `permissions`, and `overlayManager` are
        // each their own ObservableObject so other parts of the app can
        // depend on just one of them. SettingsView, however, reads all of
        // them through a single `@EnvironmentObject var appState: AppState`,
        // so their individual `objectWillChange` events are forwarded up to
        // AppState's own publisher — otherwise a change to, say,
        // `settings.isOverlayEnabled` would update the model but never
        // trigger a re-render of a view only observing `AppState`.
        for publisher in [settings.objectWillChange.eraseToAnyPublisher(),
                          detector.objectWillChange.eraseToAnyPublisher(),
                          permissions.objectWillChange.eraseToAnyPublisher(),
                          overlayManager.objectWillChange.eraseToAnyPublisher()] {
            publisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }
    }
}
