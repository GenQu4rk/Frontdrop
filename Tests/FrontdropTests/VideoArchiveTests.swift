import Foundation

@main
struct VideoArchiveTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let video = root.appendingPathComponent("wallpaper.mp4")
        let payload = Data(repeating: 42, count: 256)
        try payload.write(to: video)
        let executable = root.appendingPathComponent("never-run.command")
        try Data("must not execute".utf8).write(to: executable)
        func zip(_ name: String, _ files: [URL]) throws -> URL {
            let archive = root.appendingPathComponent(name + ".zip")
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            process.arguments = ["-q", "-j", archive.path] + files.map(\.path)
            try process.run(); process.waitUntilExit()
            precondition(process.terminationStatus == 0)
            return archive
        }
        let archive = try zip("one", [video, executable])
        let extracted = try VideoArchive.extractVideo(archive, into: root)
        precondition(extracted.lastPathComponent != video.lastPathComponent && extracted.pathExtension == "mp4")
        let extractedData = try Data(contentsOf: extracted)
        precondition(extractedData == payload, "Only the real video is streamed to a managed name")
        var bounded = false
        do { _ = try VideoArchive.extractVideo(archive, into: root, maximumBytes: 128) } catch { bounded = true }
        precondition(bounded, "Expanded data must be bounded")
        let second = root.appendingPathComponent("second.mov")
        try payload.write(to: second)
        let ambiguous = try zip("two", [video, second])
        var rejected = false
        do { _ = try VideoArchive.extractVideo(ambiguous, into: root) } catch { rejected = true }
        precondition(rejected, "Do not silently select a preview or arbitrary video")
        let noVideo = try zip("none", [executable])
        rejected = false
        do { _ = try VideoArchive.extractVideo(noVideo, into: root) } catch { rejected = true }
        precondition(rejected, "Archives without a supported video are rejected")
        print("PASS: ZIP video bytes, managed destination, expansion limit, ambiguous and non-video archive rejection")
    }
}
