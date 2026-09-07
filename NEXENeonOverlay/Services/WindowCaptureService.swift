//
//  WindowCaptureService.swift
//  NEXENeonOverlay
//
//  Captures FL Studio's own window content — and only that window's
//  content — using the public ScreenCaptureKit framework (macOS's supported
//  screen/window capture API; the same API screen recorders and streaming
//  software use). This reads already-composited pixels the window server is
//  already drawing to the screen, exactly like a screenshot, scoped to the
//  single window NEXE is already tracking. FL Studio's process, memory, and
//  files are never touched.
//

import Foundation
import ScreenCaptureKit
import CoreImage
import CoreMedia
import CoreVideo
import AppKit

final class WindowCaptureService: NSObject, ObservableObject {

    @Published private(set) var latestFrame: CIImage?

    private var stream: SCStream?
    private var currentPID: pid_t?
    private let outputQueue = DispatchQueue(label: "com.nexe.windowcapture.output")

    /// Starts capturing `pid`'s largest on-screen window. A no-op if already
    /// capturing that same process.
    func start(pid: pid_t) {
        if currentPID == pid, stream != nil { return }
        beginCapture(pid: pid)
    }

    /// Forces a fresh capture of `pid`'s window even if already capturing it
    /// — used when the tracked window is resized, since a ScreenCaptureKit
    /// stream's configuration is fixed at creation time.
    func restart(pid: pid_t) {
        beginCapture(pid: pid)
    }

    func stop() {
        currentPID = nil
        let activeStream = stream
        stream = nil
        if let activeStream {
            Task { try? await activeStream.stopCapture() }
        }
        latestFrame = nil
    }

    private var framesReceived = 0

    private func beginCapture(pid: pid_t) {
        stop()
        currentPID = pid
        framesReceived = 0
        print("[NEXE] WindowCaptureService: starting capture for pid \(pid)")

        Task { [weak self] in
            guard let self else { return }
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard self.currentPID == pid else { return }

                let candidates = content.windows.filter { $0.owningApplication?.processID == pid }
                print("[NEXE] WindowCaptureService: found \(candidates.count) window(s) owned by pid \(pid) out of \(content.windows.count) total shareable windows")
                guard let scWindow = candidates.max(by: { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }) else {
                    print("[NEXE] WindowCaptureService: no matching SCWindow for pid \(pid) — is Screen Recording access actually granted?")
                    return
                }

                self.beginStream(for: scWindow, pid: pid)
            } catch {
                print("[NEXE] WindowCaptureService: SCShareableContent fetch failed — \(error)")
            }
        }
    }

    private func beginStream(for window: SCWindow, pid: pid_t) {
        guard currentPID == pid else { return }

        let filter = SCContentFilter(desktopIndependentWindow: window)

        let configuration = SCStreamConfiguration()
        let scale = Int(NSScreen.main?.backingScaleFactor ?? 2)
        configuration.width = max(1, Int(window.frame.width)) * scale
        configuration.height = max(1, Int(window.frame.height)) * scale
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.showsCursor = false
        configuration.queueDepth = 3
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 24)

        let newStream = SCStream(filter: filter, configuration: configuration, delegate: nil)

        do {
            try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: outputQueue)
        } catch {
            print("[NEXE] WindowCaptureService: addStreamOutput failed — \(error)")
            return
        }

        stream = newStream

        Task { [weak self] in
            guard let self else { return }
            do {
                try await newStream.startCapture()
                print("[NEXE] WindowCaptureService: startCapture() succeeded, waiting for frames…")
            } catch {
                print("[NEXE] WindowCaptureService: startCapture() failed — \(error)")
                if self.stream === newStream {
                    self.stream = nil
                }
            }
        }
    }
}

extension WindowCaptureService: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let image = CIImage(cvPixelBuffer: pixelBuffer)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.latestFrame = image
            self.framesReceived += 1
            if self.framesReceived == 1 || self.framesReceived % 120 == 0 {
                print("[NEXE] WindowCaptureService: received frame #\(self.framesReceived), size \(image.extent.width)x\(image.extent.height)")
            }
        }
    }
}
