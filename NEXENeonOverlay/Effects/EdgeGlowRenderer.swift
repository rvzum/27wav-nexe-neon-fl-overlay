//
//  EdgeGlowRenderer.swift
//  NEXENeonOverlay
//
//  Turns a captured frame of FL Studio's own window into a transparent neon
//  edge-glow image: every hard edge FL Studio itself already draws — button
//  borders, panel dividers, the pattern grid, waveform outlines — becomes a
//  thin, colored, glowing line; everything else becomes transparent. This is
//  pure image processing on pixels already visible on screen (the same
//  pixels a screenshot would capture) — FL Studio's process is never read,
//  touched, or altered in any way.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import AppKit

enum EdgeGlowRenderer {

    /// Shared, reusable Core Image context (GPU-backed). Creating a new
    /// CIContext per frame would be wasteful; one long-lived context is the
    /// standard, documented Core Image usage pattern.
    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    /// Renders the neon edge-glow version of `image`, tinted with `theme`'s
    /// glow color, into a CGImage ready to hand straight to a CALayer's
    /// `contents`. Returns nil if any step of the pipeline fails — the
    /// caller simply keeps showing the previous frame in that case.
    static func render(_ image: CIImage, theme: Theme, sensitivity: Double, intensity: Double) -> CGImage? {
        let edges = CIFilter.edges()
        edges.inputImage = image
        edges.intensity = Float(1.0 + max(0, sensitivity) * 4.0)

        guard let edgeImage = edges.outputImage else { return nil }

        let bloom = CIFilter.bloom()
        bloom.inputImage = edgeImage
        bloom.radius = Float(4 + 10 * max(0, intensity))
        bloom.intensity = Float(0.6 + 0.8 * max(0, intensity))

        let bloomedImage = bloom.outputImage ?? edgeImage

        // CIEdges/CIBloom leave a mostly-black image with bright edges.
        // Re-map that brightness into the alpha channel (so the background
        // becomes fully transparent) and flatten the color everywhere else
        // to the theme's own glow color, so remaining edges read as one
        // consistent neon tint rather than whatever raw colors FL Studio
        // happened to be drawing there.
        let colorMatrix = CIFilter.colorMatrix()
        colorMatrix.inputImage = bloomedImage
        let glow = theme.glowColor
        colorMatrix.rVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        colorMatrix.gVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        colorMatrix.bVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        colorMatrix.aVector = CIVector(x: 0.30, y: 0.59, z: 0.11, w: 0)
        colorMatrix.biasVector = CIVector(x: CGFloat(glow.red), y: CGFloat(glow.green), z: CGFloat(glow.blue), w: 0)

        guard let tinted = colorMatrix.outputImage else { return nil }

        return context.createCGImage(tinted, from: image.extent)
    }
}
