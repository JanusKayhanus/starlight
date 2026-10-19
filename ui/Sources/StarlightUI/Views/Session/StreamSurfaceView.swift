import AppKit
import Metal
import QuartzCore
import SwiftUI

/// The view a stream renders into: an `NSView` backed by a `CAMetalLayer`.
///
/// This is what replaces the SDL window. The core's Metal renderer
/// (`vt_metal.mm`) currently gets its layer from `SDL_Metal_GetLayer()`; it can
/// take `metalLayer` from this view instead. Keyboard and mouse events for the
/// stream will also arrive here once input is moved off SDL.
public final class StreamSurfaceView: NSView {
    public var metalLayer: CAMetalLayer? {
        layer as? CAMetalLayer
    }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .never
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public override func makeBackingLayer() -> CALayer {
        let layer = CAMetalLayer()
        layer.device = MTLCreateSystemDefaultDevice()
        layer.pixelFormat = .bgra8Unorm
        layer.backgroundColor = NSColor.black.cgColor
        return layer
    }

    public override var acceptsFirstResponder: Bool { true }

    public override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        layer?.contentsScale = window?.backingScaleFactor ?? 2
    }
}

/// Hosts a `StreamSurfaceView` in SwiftUI.
struct StreamSurface: NSViewRepresentable {
    /// Called once, when the surface view has been created.
    var onCreate: (StreamSurfaceView) -> Void

    func makeNSView(context: Context) -> StreamSurfaceView {
        let view = StreamSurfaceView(frame: .zero)
        onCreate(view)
        return view
    }

    func updateNSView(_ nsView: StreamSurfaceView, context: Context) {}
}

/// Hands the `NSWindow` hosting a SwiftUI view to `onWindow`, for the few
/// things SwiftUI can't do itself (such as moving a window to another screen).
struct WindowAccessor: NSViewRepresentable {
    var onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> WindowReportingView {
        let view = WindowReportingView()
        view.onWindow = onWindow
        return view
    }

    func updateNSView(_ nsView: WindowReportingView, context: Context) {
        nsView.onWindow = onWindow
    }

    /// Reports its window whenever it moves into one, which can happen after
    /// SwiftUI creates it.
    final class WindowReportingView: NSView {
        var onWindow: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindow?(window)
        }
    }
}
