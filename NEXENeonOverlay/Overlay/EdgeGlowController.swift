//
//  EdgeGlowController.swift
//  NEXENeonOverlay
//
//  Bridges WindowCaptureService's raw captured frames through
//  EdgeGlowRenderer's image-processing pipeline and republishes the result
//  on the main thread as a ready-to-display CGImage. Processing happens off
//  the main thread so a slow frame never stalls the settings UI or FL
//  Studio's own responsiveness.
//

import Foundation
import Combine
import CoreImage

final class EdgeGlowController: ObservableObject {
    @Published private(set) var processedFrame: CGImage?

    private let settings: OverlaySettings
    private var cancellable: AnyCancellable?
    private let processingQueue = DispatchQueue(label: "com.nexe.edgeglow.processing", qos: .userInteractive)

    init(capture: WindowCaptureService, settings: OverlaySettings) {
        self.settings = settings

        cancellable = capture.$latestFrame
            .receive(on: processingQueue)
            .compactMap { [weak self] image -> CGImage? in
                guard let self, let image else { return nil }
                return EdgeGlowRenderer.render(
                    image,
                    theme: self.settings.theme,
                    sensitivity: self.settings.edgeSensitivity / 100.0,
                    intensity: self.settings.normalizedGlowIntensity
                )
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cgImage in
                self?.processedFrame = cgImage
            }
    }
}
