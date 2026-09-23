import AppKit
import AVFoundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var selection: SelectionController?
    private var recorder: Recorder?
    private var border: BorderWindow?
    private var statusItem: RecordingStatusItem?
    private var recordsMicrophone = false
    private var recordingStartDate = Date()
    private var quitRequested = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        Task { @MainActor in
            // Ask before the selection overlay goes up; it would cover the prompt.
            let allowed = await AVCaptureDevice.requestAccess(for: .audio)
            recordsMicrophone = allowed && AVCaptureDevice.default(for: .audio) != nil
            beginSelection()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let recorder else { return .terminateNow }
        // Save the recording first; quit() replies once it's in Downloads.
        quitRequested = true
        statusItem?.remove()
        statusItem = nil
        Task { await recorder.stop() }
        return .terminateLater
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        guard recorder != nil else { return nil }
        let menu = NSMenu()
        menu.addItem(withTitle: "Stop Recording", action: #selector(stopRecording), keyEquivalent: "")
            .target = self
        return menu
    }

    // MARK: - Flow

    private func beginSelection() {
        selection = SelectionController { [weak self] cgRect in
            guard let self else { return }
            self.selection = nil
            if let cgRect {
                self.startRecording(region: cgRect)
            } else {
                NSApp.terminate(nil)
            }
        }
        selection?.begin()
    }

    private func startRecording(region cgRect: CGRect) {
        border = BorderWindow(around: cgRect)
        let recorder = Recorder()
        recorder.onFinished = { [weak self] result in
            self?.recordingFinished(result)
        }

        Task { @MainActor in
            do {
                try await recorder.start(region: cgRect, microphone: recordsMicrophone)
                self.recorder = recorder
                recordingStartDate = Date()
                statusItem = RecordingStatusItem(target: self, action: #selector(stopRecording))
                // Hand focus back to the app being recorded.
                NSApp.hide(nil)
            } catch {
                border?.orderOut(nil)
                border = nil
                presentFailure(error)
            }
        }
    }

    @objc private func stopRecording() {
        statusItem?.remove()
        statusItem = nil
        Task { await recorder?.stop() }
    }

    private func recordingFinished(_ result: Result<URL, Error>) {
        statusItem?.remove()
        statusItem = nil
        border?.orderOut(nil)
        border = nil
        switch result {
        case .success(let file):
            save(file)
        case .failure(let error):
            presentFailure(error)
        }
    }

    private func save(_ file: URL) {
        let recordedAt = recordingStartDate
        Task { @MainActor in
            do {
                let saved = try await Task.detached {
                    try RecordingFile.moveToDownloads(file, recordedAt: recordedAt)
                }.value
                NSWorkspace.shared.activateFileViewerSelecting([saved])
            } catch {
                NSWorkspace.shared.activateFileViewerSelecting([file])
                showAlert(title: "Couldn't save to Downloads",
                          message: error.localizedDescription
                            + "\n\nThe recording is at \(file.path).",
                          button: "OK")
            }
            quit()
        }
    }

    private func quit() {
        recorder = nil
        if quitRequested {
            NSApp.reply(toApplicationShouldTerminate: true)
        } else {
            NSApp.terminate(nil)
        }
    }

    private func presentFailure(_ error: Error) {
        showAlert(title: "Could not record the screen",
                  message: error.localizedDescription
                    + "\n\nIf this is the first launch, allow PortionRecord in System Settings → "
                    + "Privacy & Security → Screen & System Audio Recording, then reopen it.",
                  button: "Quit")
        quit()
    }

    private func showAlert(title: String, message: String, button: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: button)
        NSApp.unhide(nil)
        NSApp.activate()
        alert.runModal()
    }

    // MARK: - Menu

    private func buildMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Stop Recording",
                        action: #selector(stopRecording),
                        keyEquivalent: ".")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit PortionRecord",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }
}
