import CoreGraphics
import Testing
@testable import PortionRecord

struct PixelAlignmentTests {
    private let dragSelection = CGRect(x: 100.3711, y: 50.6133, width: 801.0977, height: 500.7109)

    @Test func snapsDragSelectionsToWholeRetinaPixels() {
        let rect = Coordinates.pixelAligned(dragSelection, scale: 2)
        #expect(rect == CGRect(x: 100.5, y: 50.5, width: 801, height: 500))
    }

    @Test func snapsDragSelectionsToWholePixelsWithEvenSizeAt1x() {
        let rect = Coordinates.pixelAligned(dragSelection, scale: 1)
        #expect(rect == CGRect(x: 100, y: 51, width: 800, height: 500))
    }

    @Test func leavesAlignedRectsUnchanged() {
        let rect = CGRect(x: 10, y: 20, width: 640, height: 400)
        #expect(Coordinates.pixelAligned(rect, scale: 2) == rect)
    }

    @Test func recordsAlignedSelectionsAtExactSourcePixelSize() {
        let rect = Coordinates.pixelAligned(dragSelection, scale: 2)
        let size = Recorder.outputSize(for: rect.size, scale: 2)
        #expect(size == (Int(rect.width * 2), Int(rect.height * 2)))
    }
}
