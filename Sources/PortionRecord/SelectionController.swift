import AppKit

/// Full-screen dimmed overlays on every display; the user drags out a rectangle.
/// Completion receives the selection in global CoreGraphics (top-left origin)
/// coordinates, clipped to the display it was drawn on, or nil if cancelled
/// with Esc.
final class SelectionController {
    private var overlays: [NSWindow] = []
    private var keyMonitor: Any?
    private let completion: (CGRect?) -> Void

    init(completion: @escaping (CGRect?) -> Void) {
        self.completion = completion
    }

    func begin() {
        for screen in NSScreen.screens {
            let window = OverlayWindow(contentRect: screen.frame,
                                       styleMask: .borderless,
                                       backing: .buffered,
                                       defer: false)
            window.isReleasedWhenClosed = false
            window.backgroundColor = .clear
            window.isOpaque = false
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.setFrame(screen.frame, display: true)

            let view = SelectionView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.onSelected = { [weak self] globalNSRect in
                self?.finish(with: Coordinates.cgRect(fromGlobalNS: globalNSRect))
            }
            window.contentView = view
            window.makeKeyAndOrderFront(nil)
            overlays.append(window)
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Esc
                self?.finish(with: nil)
                return nil
            }
            return event
        }
        NSApp.activate(ignoringOtherApps: true)
        NSCursor.crosshair.set()
    }

    private func finish(with rect: CGRect?) {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        overlays.forEach { $0.orderOut(nil) }
        overlays.removeAll()
        NSCursor.arrow.set()
        completion(rect)
    }
}

private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

private final class SelectionView: NSView {
    var onSelected: ((NSRect) -> Void)?

    private var startPoint: NSPoint?
    private var selectionRect: NSRect = .zero

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        selectionRect = .zero
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)
        // A recording covers one display, so keep the selection on this one.
        selectionRect = NSRect(x: min(start.x, current.x),
                               y: min(start.y, current.y),
                               width: abs(start.x - current.x),
                               height: abs(start.y - current.y))
            .intersection(bounds)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer { startPoint = nil }
        guard selectionRect.width >= 40, selectionRect.height >= 40,
              let window = window else {
            selectionRect = .zero
            needsDisplay = true
            return
        }
        let inWindow = convert(selectionRect, to: nil)
        onSelected?(window.convertToScreen(inWindow))
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.35).setFill()
        bounds.fill()

        if selectionRect.width > 0 {
            NSColor.clear.setFill()
            selectionRect.fill(using: .copy)
            NSColor.white.setStroke()
            let border = NSBezierPath(rect: selectionRect.insetBy(dx: -0.5, dy: -0.5))
            border.lineWidth = 1
            border.stroke()
        } else {
            drawInstructions()
        }
    }

    private func drawInstructions() {
        let text = "Drag to select the region to record  ·  Esc to cancel"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 20, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = text.size(withAttributes: attributes)
        let padding: CGFloat = 16
        let box = NSRect(x: bounds.midX - size.width / 2 - padding,
                         y: bounds.midY - size.height / 2 - padding / 2,
                         width: size.width + padding * 2,
                         height: size.height + padding)
        NSColor.black.withAlphaComponent(0.6).setFill()
        NSBezierPath(roundedRect: box, xRadius: 10, yRadius: 10).fill()
        text.draw(at: NSPoint(x: box.midX - size.width / 2, y: box.midY - size.height / 2),
                  withAttributes: attributes)
    }
}
