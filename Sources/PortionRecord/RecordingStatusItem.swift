import AppKit

/// Menu bar button shown while recording: a stop icon and the elapsed time.
/// Clicking it stops the recording.
final class RecordingStatusItem {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let startDate = Date()
    private var timer: Timer?

    init(target: AnyObject, action: Selector) {
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "stop.circle.fill",
                                   accessibilityDescription: "Stop Recording")
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            button.toolTip = "Stop recording and save to Downloads"
            button.target = target
            button.action = action
        }
        showElapsedTime()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.showElapsedTime()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func remove() {
        timer?.invalidate()
        NSStatusBar.system.removeStatusItem(item)
    }

    private func showElapsedTime() {
        let seconds = Int(Date().timeIntervalSince(startDate))
        item.button?.title = String(format: " %d:%02d", seconds / 60, seconds % 60)
    }
}
