import AppKit
import os
import ScreenCaptureKit

/// Records a region of one display to an MP4. SCRecordingOutput does the
/// H.264/AAC encoding and mixes system audio and the microphone into a single
/// audio track, which is the only one browsers and chat-app previews play.
final class Recorder: NSObject, SCStreamDelegate, SCStreamOutput, SCRecordingOutputDelegate {
    /// 4K UHD's pixel count. Larger frames push H.264 past Level 5.2, which
    /// many non-Apple hardware decoders can't play.
    static let maxPixelCount: CGFloat = 3840 * 2160

    /// Called once, on the main queue, with the finished file or the error
    /// that ended the recording.
    var onFinished: ((Result<URL, Error>) -> Void)?

    let fileURL = FileManager.default.temporaryDirectory
        .appending(path: "\(UUID().uuidString).mp4")

    private var stream: SCStream?
    private var recordingOutput: SCRecordingOutput?
    private var nudge: FrameNudgeWindow?
    private var isFinished = false
    private let completeFrames = OSAllocatedUnfairLock(initialState: 0)
    private let sampleQueue = DispatchQueue(label: "portionrecord.capture")

    /// `region` is in global CoreGraphics (top-left origin) coordinates and
    /// should lie on a single display.
    @MainActor
    func start(region: CGRect, microphone: Bool) async throws {
        let nudge = FrameNudgeWindow(inside: region)
        self.nudge = nudge
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                true, onScreenWindowsOnly: true)

            let center = CGPoint(x: region.midX, y: region.midY)
            guard let display = content.displays.first(where: {
                CGDisplayBounds($0.displayID).contains(center)
            }) else {
                throw RecorderError.noDisplayForSelection
            }
            let displayBounds = CGDisplayBounds(display.displayID)
            let rectInDisplay = region
                .intersection(displayBounds)
                .offsetBy(dx: -displayBounds.origin.x, dy: -displayBounds.origin.y)

            let filter = Self.filter(for: display, in: content, keeping: nudge)
            let size = Self.outputSize(for: rectInDisplay.size,
                                       scale: CGFloat(filter.pointPixelScale))

            let config = SCStreamConfiguration()
            config.sourceRect = rectInDisplay
            config.width = size.width
            config.height = size.height
            config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
            config.showsCursor = true
            config.capturesAudio = true
            config.captureMicrophone = microphone

            let recordingConfig = SCRecordingOutputConfiguration()
            recordingConfig.outputURL = fileURL
            recordingConfig.outputFileType = .mp4
            recordingConfig.videoCodecType = .h264
            let recordingOutput = SCRecordingOutput(configuration: recordingConfig, delegate: self)

            let stream = SCStream(filter: filter, configuration: config, delegate: self)
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)
            try stream.addRecordingOutput(recordingOutput)
            try await stream.startCapture()
            self.stream = stream
            self.recordingOutput = recordingOutput
        } catch {
            nudge.orderOut(nil)
            self.nudge = nil
            throw error
        }
    }

    /// Stops capturing. `onFinished` fires once the file is written.
    @MainActor
    func stop() async {
        guard let stream else { return }
        self.stream = nil
        await forceFinalFrame()
        do {
            try await stream.stopCapture()
            failIfRecordingOutputStaysSilent(RecorderError.recordingDidNotFinish)
        } catch {
            failIfRecordingOutputStaysSilent(error)
        }
    }

    /// Pixel size for capturing `points` at `scale`: native resolution, scaled
    /// down to `maxPixelCount` when larger, and rounded down to even numbers
    /// because H.264's 4:2:0 chroma needs them.
    static func outputSize(for points: CGSize, scale: CGFloat) -> (width: Int, height: Int) {
        var width = points.width * scale
        var height = points.height * scale
        let fit = (maxPixelCount / (width * height)).squareRoot()
        if fit < 1 {
            width *= fit
            height *= fit
        }
        return (max(2, Int(width) & ~1), max(2, Int(height) & ~1))
    }

    /// Keeps this app's own windows (the outline, the menu bar item) out of the
    /// recording, except the nudge window, which has to be captured to work.
    private static func filter(for display: SCDisplay, in content: SCShareableContent,
                               keeping nudge: FrameNudgeWindow) -> SCContentFilter {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        guard let ownApp = content.applications.first(where: { $0.processID == ownPID }) else {
            return SCContentFilter(display: display, excludingWindows: [])
        }
        let nudgeWindows = content.windows.filter { $0.windowID == CGWindowID(nudge.windowNumber) }
        return SCContentFilter(display: display, excludingApplications: [ownApp],
                               exceptingWindows: nudgeWindows)
    }

    /// ScreenCaptureKit only delivers a frame when pixels change, and
    /// SCRecordingOutput ends the video track 1/15 s after the last one. If the
    /// region sat still before Stop, the video track would end early, and
    /// ffmpeg-based players and transcoders treat the rest as having no video.
    @MainActor
    private func forceFinalFrame() async {
        let before = completeFrames.withLock { $0 }
        nudge?.flip()
        let deadline = Date.now.addingTimeInterval(0.5)
        while completeFrames.withLock({ $0 }) == before, Date.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    /// SCRecordingOutput normally reports how the file ended on its own; this
    /// only keeps the app from waiting forever if it never does.
    private func failIfRecordingOutputStaysSilent(_ error: Error) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { self.finish(.failure(error)) }
    }

    private func finish(_ result: Result<URL, Error>) {
        guard !isFinished else { return }
        isFinished = true
        stream = nil
        recordingOutput = nil
        nudge?.orderOut(nil)
        nudge = nil
        onFinished?(result)
    }

    // MARK: - SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard type == .screen,
              let attachments = (CMSampleBufferGetSampleAttachmentsArray(
                  sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]])?.first,
              let statusRaw = attachments[.status] as? Int,
              SCFrameStatus(rawValue: statusRaw) == .complete else { return }
        completeFrames.withLock { $0 += 1 }
    }

    // MARK: - SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async {
            self.stream = nil
            self.failIfRecordingOutputStaysSilent(error)
        }
    }

    // MARK: - SCRecordingOutputDelegate

    func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        DispatchQueue.main.async { self.finish(.success(self.fileURL)) }
    }

    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        DispatchQueue.main.async { self.finish(.failure(error)) }
    }
}

enum RecorderError: LocalizedError {
    case noDisplayForSelection
    case recordingDidNotFinish

    var errorDescription: String? {
        switch self {
        case .noDisplayForSelection:
            return "The selected region is not on any active display."
        case .recordingDidNotFinish:
            return "The recording never finished writing to disk."
        }
    }
}

/// A 2×2 pt, 2%-opaque window in the region's top-left corner. Changing its
/// color makes ScreenCaptureKit deliver a frame on demand.
private final class FrameNudgeWindow: NSWindow {
    private var isDark = false

    init(inside cgGlobalRect: CGRect) {
        let corner = CGRect(origin: cgGlobalRect.origin, size: CGSize(width: 2, height: 2))
        super.init(contentRect: Coordinates.nsRect(fromGlobalCG: corner),
                   styleMask: .borderless, backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        canHide = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        applyColor()
        orderFrontRegardless()
    }

    func flip() {
        isDark.toggle()
        applyColor()
    }

    private func applyColor() {
        backgroundColor = (isDark ? NSColor.black : NSColor.white).withAlphaComponent(0.02)
    }
}
