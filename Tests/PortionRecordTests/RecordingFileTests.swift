import Foundation
import Testing
@testable import PortionRecord

struct RecordingFileTests {
    @Test func namesRecordingsLikeMacOSScreenshots() throws {
        let utc = try #require(TimeZone(identifier: "UTC"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let date = try #require(calendar.date(from: DateComponents(
            year: 2026, month: 9, day: 22, hour: 15, minute: 36, second: 12)))

        #expect(RecordingFile.baseName(for: date, timeZone: utc)
            == "Screen Recording 2026-09-22 at 15.36.12")
    }

    @Test func usesBaseNameWhenFree() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(RecordingFile.unusedURL(in: directory, baseName: "Clip").lastPathComponent
            == "Clip.mp4")
    }

    @Test func numbersNameWhenTaken() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        for name in ["Clip.mp4", "Clip 2.mp4"] {
            FileManager.default.createFile(atPath: directory.appending(path: name).path, contents: nil)
        }

        #expect(RecordingFile.unusedURL(in: directory, baseName: "Clip").lastPathComponent
            == "Clip 3.mp4")
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
