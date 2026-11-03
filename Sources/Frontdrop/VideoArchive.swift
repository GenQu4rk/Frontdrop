import Foundation

/// Streams one video out of a ZIP to a managed filename; never extracts archive paths or runs contents.
enum VideoArchive {
    private struct ArchiveError: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }
    static func extractVideo(_ archive: URL, into directory: URL, maximumBytes: Int = 1_073_741_824) throws -> URL {
        var listing = Data()
        try run(["-Z1", archive.path], maximumBytes: 1_048_576) { listing.append($0) }
        guard let text = String(data: listing, encoding: .utf8) else { throw ArchiveError("This ZIP uses unsupported filenames. Unzip it in Finder, then use Import Video.") }
        let entries = text.split(separator: "\n").map(String.init)
        let videos = entries.filter { ["mp4", "m4v", "mov"].contains(URL(fileURLWithPath: $0).pathExtension.lowercased()) }
        guard videos.count == 1, let entry = videos.first else {
            if entries.contains(where: { $0.lowercased().hasSuffix(".mlw") }) {
                throw ArchiveError("This download contains an MLW wallpaper for MyLiveWallpapers' Windows software. Frontdrop needs an MP4 or MOV version. Choose another video download or source.")
            }
            throw ArchiveError("This ZIP must contain one MP4, M4V or MOV video. Unzip it in Finder and choose the actual wallpaper with Import Video.")
        }
        guard !entry.hasPrefix("/"), !entry.hasPrefix("-"),
              !entry.split(separator: "/").contains(".."),
              entry.rangeOfCharacter(from: CharacterSet(charactersIn: "\\*?[]\r")) == nil else {
            throw ArchiveError("This ZIP has an unsupported video path. Unzip it in Finder, then use Import Video.")
        }
        let destination = directory.appendingPathComponent(UUID().uuidString + "." + URL(fileURLWithPath: entry).pathExtension.lowercased())
        guard FileManager.default.createFile(atPath: destination.path, contents: nil) else { throw ArchiveError("Could not prepare the downloaded video.") }
        let output = try FileHandle(forWritingTo: destination)
        do {
            try run(["-p", archive.path, entry], maximumBytes: maximumBytes) { try output.write(contentsOf: $0) }
            try output.close()
            return destination
        } catch {
            try? output.close()
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }
    private static func run(_ arguments: [String], maximumBytes: Int, consume: (Data) throws -> Void) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let timeout = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timeout.schedule(deadline: .now() + 60)
        timeout.setEventHandler { if process.isRunning { process.terminate() } }
        timeout.resume()
        defer {
            timeout.cancel()
            if process.isRunning { process.terminate() }
            try? pipe.fileHandleForReading.close()
            process.waitUntilExit()
        }
        var total = 0
        while let data = try pipe.fileHandleForReading.read(upToCount: 65_536), !data.isEmpty {
            total += data.count
            guard total <= maximumBytes else { throw ArchiveError("This ZIP expands beyond Frontdrop's video limit. Unzip it in Finder and import a smaller video.") }
            try consume(data)
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw ArchiveError("This ZIP could not be read. Try the download again, or unzip it in Finder and use Import Video.") }
    }
}
