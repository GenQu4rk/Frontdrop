import Foundation

@main
struct WorkshopVideoTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var checks = 0
        func expect(_ value: Bool, _ message: String) { precondition(value, message); checks += 1 }
        func project(_ json: String) throws { try Data(json.utf8).write(to: root.appendingPathComponent("project.json")) }
        func rejects(_ json: String) throws -> Bool {
            try project(json)
            do { _ = try WorkshopVideoProject.read(root); return false } catch { return true }
        }
        try Data([0]).write(to: root.appendingPathComponent("scene.mp4"))
        try project(#"{"type":"video","file":"scene.mp4","title":"Space Journey","workshopid":"123456789","tags":["Sci-Fi"]}"#)
        let video = try WorkshopVideoProject.read(root)
        expect(video.title == "Space Journey" && video.videoURL.lastPathComponent == "scene.mp4", "Use the manifest's real title and video; AVFoundation validates media later")
        expect(video.sourceURL?.absoluteString == "https://steamcommunity.com/sharedfiles/filedetails/?id=123456789", "Retain Workshop attribution")
        expect(try rejects(#"{"type":"scene","file":"scene.pkg"}"#), "Reject interactive scenes rather than import a preview")
        expect(try rejects(#"{"type":"web","file":"index.html"}"#), "Never execute Workshop HTML")
        expect(try rejects(#"{"type":"video","file":"../outside.mp4"}"#), "Reject parent traversal")
        expect(try rejects(#"{"type":"video","file":"/tmp/outside.mp4"}"#), "Reject absolute paths")
        expect(try rejects(#"{"type":"video","file":"missing.mp4"}"#), "Missing files are reported")
        expect(try rejects(#"{"type":"video","file":"scene.exe"}"#), "Reject executables")
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("outside.mp4"), withDestinationURL: URL(fileURLWithPath: "/tmp/outside.mp4"))
        expect(try rejects(#"{"type":"video","file":"outside.mp4"}"#), "Reject symlinks escaping the selected project")
        try project(#"{"type":"video","file":"scene.mp4","workshopid":"123&other=bad"}"#)
        expect(try WorkshopVideoProject.read(root).sourceURL == nil, "Malformed attribution IDs do not create external links")
        print("PASS: \(checks) Workshop video import checks")
    }
}
