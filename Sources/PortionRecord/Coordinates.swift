import AppKit

// AppKit uses a bottom-left-origin global space; CoreGraphics/ScreenCaptureKit
// use top-left origin. Both are anchored to the primary screen.
enum Coordinates {
    static func cgRect(fromGlobalNS ns: NSRect) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.maxY ?? 0
        return CGRect(x: ns.origin.x,
                      y: primaryHeight - ns.maxY,
                      width: ns.width,
                      height: ns.height)
    }

    static func nsRect(fromGlobalCG cg: CGRect) -> NSRect {
        let primaryHeight = NSScreen.screens.first?.frame.maxY ?? 0
        return NSRect(x: cg.origin.x,
                      y: primaryHeight - cg.maxY,
                      width: cg.width,
                      height: cg.height)
    }

    /// Snaps a rect in points to whole pixels at `scale`, with even pixel
    /// dimensions. Drag selections have sub-point coordinates, and a
    /// `sourceRect` off the pixel grid makes ScreenCaptureKit resample every
    /// frame, which blurs text.
    static func pixelAligned(_ rect: CGRect, scale: CGFloat) -> CGRect {
        CGRect(x: (rect.minX * scale).rounded() / scale,
               y: (rect.minY * scale).rounded() / scale,
               width: max(2, (rect.width * scale / 2).rounded(.down) * 2) / scale,
               height: max(2, (rect.height * scale / 2).rounded(.down) * 2) / scale)
    }
}
