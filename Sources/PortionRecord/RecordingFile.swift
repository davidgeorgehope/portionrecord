import Foundation

/// Names finished recordings like macOS screenshots and moves them into Downloads.
enum RecordingFile {
    static func baseName(for date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return "Screen Recording \(formatter.string(from: date))"
    }

    /// `directory/baseName.mp4`, or `baseName 2.mp4`, `baseName 3.mp4`, … if taken.
    static func unusedURL(in directory: URL, baseName: String) -> URL {
        var candidate = directory.appending(path: "\(baseName).mp4")
        var number = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appending(path: "\(baseName) \(number).mp4")
            number += 1
        }
        return candidate
    }

    /// Blocks on the Downloads permission prompt the first time, so call it
    /// off the main thread.
    static func moveToDownloads(_ file: URL, recordedAt date: Date) throws -> URL {
        let destination = unusedURL(in: .downloadsDirectory, baseName: baseName(for: date))
        try FileManager.default.moveItem(at: file, to: destination)
        return destination
    }
}
