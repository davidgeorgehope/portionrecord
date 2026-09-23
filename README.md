# PortionRecord

Record just a **portion** of your Mac's screen, with audio, straight to an MP4
in your Downloads folder.

Drag-select any region of your screen and PortionRecord captures it at native
resolution along with system audio and your microphone. Click stop in the menu
bar and the finished `.mp4` lands in `~/Downloads`, revealed in Finder.

## Features

- **Drag to select** any region on any display
- **MP4 output** (H.264 + AAC) that plays everywhere: QuickTime, browsers,
  Slack, Google Drive
- **System audio and microphone**, mixed into one track
- **Native resolution** (Retina included), 30 fps, cursor included
- **Red outline** on screen shows exactly what's being recorded
- **Self-exclusion**: PortionRecord's own outline and menu bar item never show
  up in the recording
- Native Swift + [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit),
  no dependencies

## Install

Requires macOS 15+ and the Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/davidgeorgehope/portionrecord.git
cd portionrecord
./build.sh
open dist/PortionRecord.app
```

App icon lives in `Resources/AppIcon.icns` (Grok Imagine). Regenerate with
`./generate_icon.sh` then `./build.sh`.

## Usage

1. Launch PortionRecord. The screen dims; drag to select the region to record
   (Esc cancels).
2. Recording starts right away. A red outline marks the captured area, and a
   stop button with the elapsed time appears in the menu bar.
3. Click the stop button. The recording is saved to Downloads as
   `Screen Recording 2026-09-22 at 15.36.12.mp4`, Finder shows it, and
   PortionRecord quits.

| To stop and save | |
|---|---|
| Menu bar | Click the ⏹ button |
| Dock | Right-click the icon → Stop Recording |
| Keyboard (with PortionRecord active) | Cmd+. or Cmd+Q |

Quitting always saves the recording first, including on logout or shutdown.

## Permissions

The first run asks for three things:

- **Microphone**, before the region picker. Deny it to record system audio only.
- **Screen & System Audio Recording**, the first time you select a region.
  Allow it in System Settings → Privacy & Security, then reopen PortionRecord.
- **Downloads folder**, the first time a recording is saved. If you deny it,
  the recording stays in a temporary folder and Finder shows you where.

## How it works

PortionRecord streams the selected display rectangle
(`SCStreamConfiguration.sourceRect`) with system audio and microphone capture
enabled, and attaches an `SCRecordingOutput` that encodes the stream straight
to MP4. ScreenCaptureKit mixes both audio sources into a single AAC track,
which matters because browsers and chat-app previews only play the first audio
track. The capture filter excludes PortionRecord's own windows, which is why
the outline never appears in the video.

One wrinkle: ScreenCaptureKit only delivers a frame when pixels change, and the
recording output ends the video track shortly after the last frame. If the
region sat still before you hit stop, the video would end early, and
ffmpeg-based players and transcoders would drop the rest. To prevent that, a
2×2 pt, 2%-opaque window in the region's corner changes color at stop time,
forcing one final frame.

Source layout:

| File | Purpose |
|---|---|
| `SelectionController.swift` | Dimmed drag-to-select overlay across all displays |
| `Recorder.swift` | ScreenCaptureKit stream and MP4 recording of the selected rectangle |
| `RecordingStatusItem.swift` | Menu bar stop button with elapsed time |
| `RecordingFile.swift` | File naming and the move into Downloads |
| `BorderWindow.swift` | Click-through outline around the recorded region |
| `AppDelegate.swift` | Wires selection → recording → save together |

## Development

```bash
./test.sh
```

`test.sh` wraps `swift test` and adds the Swift Testing search paths SwiftPM
misses when only the Command Line Tools are installed.

## FAQ

**Is anything uploaded anywhere?**
No. PortionRecord never touches the network. Recordings are written locally
and moved into your Downloads folder.

**Why is my voice echoed in the recording?**
With speakers, the microphone also picks up system audio, so it's recorded
twice. Use headphones when recording anything with sound.

**How big can the region be?**
Anything on one display. Regions larger than 4K UHD (for example a full 5K
Retina screen) are scaled down to 4K so the H.264 stream stays playable on
non-Apple hardware decoders.

## License

[MIT](LICENSE)
