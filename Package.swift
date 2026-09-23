// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PortionRecord",
    // SCRecordingOutput and ScreenCaptureKit microphone capture need macOS 15.
    platforms: [.macOS("15.0")],
    targets: [
        .executableTarget(
            name: "PortionRecord",
            path: "Sources/PortionRecord"
        ),
        .testTarget(
            name: "PortionRecordTests",
            dependencies: ["PortionRecord"],
            path: "Tests/PortionRecordTests"
        ),
    ]
)
