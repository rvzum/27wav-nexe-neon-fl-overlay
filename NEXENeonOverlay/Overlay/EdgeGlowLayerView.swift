//
//  EdgeGlowLayerView.swift
//  NEXENeonOverlay
//
//  Displays the latest processed LIVE EDGE GLOW frame (see EdgeGlowRenderer)
//  as raw CALayer contents. Setting an already-rendered image straight onto
//  a layer is far cheaper per frame than re-composing a SwiftUI view tree,
//  so this stays smooth even while new frames keep arriving from
//  WindowCaptureService.
//

import SwiftUI
import AppKit

struct EdgeGlowLayerView: NSViewRepresentable {
    let image: CGImage?

    func makeNSView(context: Context) -> LayerHostingView {
        let view = LayerHostingView()
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: LayerHostingView, context: Context) {
        nsView.layer?.contents = image
    }
}

final class LayerHostingView: NSView {
    override var isFlipped: Bool { true }

    override func makeBackingLayer() -> CALayer {
        let layer = CALayer()
        layer.contentsGravity = .resizeAspect
        layer.magnificationFilter = .trilinear
        return layer
    }
}
