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
}
