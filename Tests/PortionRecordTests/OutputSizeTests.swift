import CoreGraphics
import Testing
@testable import PortionRecord

struct OutputSizeTests {
    @Test func keepsRetinaDisplaysAtNativeResolution() {
        let size = Recorder.outputSize(for: CGSize(width: 1512, height: 982), scale: 2)
        #expect(size == (3024, 1964))
    }

    @Test func keepsUltrawideDisplaysAtNativeResolution() {
        let size = Recorder.outputSize(for: CGSize(width: 5120, height: 1440), scale: 1)
        #expect(size == (5120, 1440))
    }

    @Test func scales5KRetinaDownTo4K() {
        let size = Recorder.outputSize(for: CGSize(width: 2560, height: 1440), scale: 2)
        #expect(size == (3840, 2160))
    }

    @Test func roundsDownToEvenPixels() {
        let size = Recorder.outputSize(for: CGSize(width: 401.5, height: 301), scale: 1)
        #expect(size == (400, 300))
    }

    @Test func keepsLargeRegionsWithinPixelBudgetAndAspectRatio() {
        let size = Recorder.outputSize(for: CGSize(width: 3000, height: 2000), scale: 2)
        #expect(CGFloat(size.width * size.height) <= Recorder.maxPixelCount)
        #expect(size.width % 2 == 0 && size.height % 2 == 0)
        #expect(abs(Double(size.width) / Double(size.height) - 1.5) < 0.01)
    }
}
