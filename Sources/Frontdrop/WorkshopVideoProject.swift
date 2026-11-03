import Foundation

/// Reads a user-selected video project. Scene packages, scripts and previews are never run or imported.
struct WorkshopVideoProject {
    let title: String
    let videoURL: URL
    let sourceURL: URL?
    private struct Manifest: Decodable {
        let type: String
        let file: String
        let title: String?
        let workshopid: String?
    }
    private struct ImportError: LocalizedError {
        let errorDescription: String?
        init(_ description: String) { errorDescription = description }
    }
    static func read(_ directory: URL) throws -> Self {
        let root = directory.resolvingSymlinksInPath().standardizedFileURL
        let manifestURL = root.appendingPathComponent("project.json")
        guard (try? manifestURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map({ $0 < 1_048_576 }) == true else {
            throw ImportError("Choose one wallpaper's folder containing project.json, not the whole 431960 Workshop folder.")
        }
        let project = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))
        guard project.type.lowercased() == "video" else {
            throw ImportError("This is a \(project.type) wallpaper. Frontdrop imports Video projects; Scene, Web and Application projects need Wallpaper Engine's renderer. Look for a video version from the creator.")
        }
        let path = project.file.replacingOccurrences(of: "\\", with: "/")
        let video = root.appendingPathComponent(path).resolvingSymlinksInPath().standardizedFileURL
        guard !path.hasPrefix("/"), video.path.hasPrefix(root.path + "/"),
              ["mp4", "m4v", "mov"].contains(video.pathExtension.lowercased()),
              (try? video.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
            throw ImportError("The project needs a playable MP4, M4V or MOV inside its folder. Download the complete Video project, or convert its video to H.264/HEVC MP4 first.")
        }
        let id = project.workshopid ?? root.lastPathComponent
        let source = !id.isEmpty && id.utf8.allSatisfy { (48...57).contains($0) }
            ? URL(string: "https://steamcommunity.com/sharedfiles/filedetails/?id=" + id) : nil
        let title = project.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        return Self(title: String((title?.isEmpty == false ? title! : video.deletingPathExtension().lastPathComponent).prefix(180)), videoURL: video, sourceURL: source)
    }
}
