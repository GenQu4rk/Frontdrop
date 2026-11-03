import AppKit
import AVFoundation

@main
struct IntegrationTests {
    @MainActor static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Frontdrop-tests-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = LibraryStore(directory: root)
        let source = URL(fileURLWithPath: CommandLine.arguments[1])
        await model.importVideos([source])
        precondition(model.error == nil, "Valid video import failed: \(model.error ?? "")")
        precondition(model.state.imports.count == 1, "Video missing from library")
        let scene = model.state.imports[0]
        let copied = model.videoURL(for: scene)!
        precondition(copied != source && FileManager.default.fileExists(atPath: copied.path), "Import must own its copy")
        model.favourite(scene)
        model.apply(scene)
        let restored = LibraryStore(directory: root)
        precondition(restored.state.imports.count == 1 && restored.state.favourites.contains(scene.id), "Library not persisted")
        precondition(restored.state.activeID == scene.id && restored.state.enabled, "Applied scene not persisted")
        print("PASS: real video imported, copied, thumbnailed, favourited and restored")
        let desktop = DesktopEngine(store: model)
        desktop.start()
        func wallpaperWindows() -> [Int] {
            NSApplication.shared.windows.filter { $0 is DesktopWindow }.map(\.windowNumber).sorted()
        }
        let originalWindows = wallpaperWindows()
        precondition(!originalWindows.isEmpty, "Desktop fixture must create real wallpaper windows")
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: NSApplication.shared)
        precondition(wallpaperWindows() == originalWindows, "A Dock/menu-bar-only screen notification must preserve existing desktop players")
        let originalPlayers = NSApplication.shared.windows.compactMap { ($0 as? DesktopWindow)?.contentView as? VideoSceneView }
        precondition(!originalPlayers.isEmpty && originalPlayers.allSatisfy { $0.playerLayer.videoGravity == .resizeAspect }, "Desktop video must initially show the entire frame")
        model.setVideoFraming(.fill, for: scene)
        desktop.reconcile()
        precondition(wallpaperWindows() == originalWindows && originalPlayers.allSatisfy { $0.playerLayer.videoGravity == .resizeAspectFill }, "Changing framing must update existing players without rebuilding wallpaper windows")
        let framedRestore = LibraryStore(directory: root)
        precondition(framedRestore.active.framing == .fill, "Per-wallpaper framing must persist")
        model.setVideoFraming(.fit, for: model.active)
        desktop.reconcile()
        precondition(originalPlayers.allSatisfy { $0.playerLayer.videoGravity == .resizeAspect }, "Fit must restore the complete frame")
        print("PASS: desktop Fit/Fill updates live without rebuilding players and persists per wallpaper")
        desktop.shutdown()
        print("PASS: unchanged display geometry keeps the desktop windows and players")
        let playerView = VideoSceneView(url: copied)
        var playbackError: Error?
        playerView.onError = { playbackError = $0 }
        playerView.setPlaying(true)
        try await Task.sleep(nanoseconds: 5_000_000_000)
        precondition(playbackError == nil, "Video playback failed")
        precondition(playerView.looper.loopCount > 0, "Video did not loop")
        playerView.setPlaying(false)
        let pauseTime = playerView.player.currentTime().seconds
        try await Task.sleep(nanoseconds: 400_000_000)
        precondition(abs(playerView.player.currentTime().seconds-pauseTime) < 0.1, "Pause did not hold frame")
        precondition(playerView.player.isMuted, "Wallpaper video must be muted")
        print("PASS: video actually loops, pauses, and stays muted")
        model.stop()
        precondition(!model.state.enabled, "Stop did not persist")
        let bad = root.appendingPathComponent("invalid.mp4")
        try Data("not a video".utf8).write(to: bad)
        await model.importVideos([bad])
        precondition(model.error != nil && model.state.imports.count == 1, "Invalid media should produce an error without adding an entry")
        model.remove(scene)
        precondition(model.state.imports.isEmpty && !model.state.favourites.contains(scene.id), "Remove must clear video and favourite")
        precondition(FileManager.default.fileExists(atPath: source.path), "Remove must keep original")
        print("PASS: invalid video rejected; removal preserves original")
        model.error = nil
        let origin = URL(string: "https://motionbgs.com/cloudscape")!
        let downloaded = try await model.importVideo(source, title: "Cloudscape", sourceURL: origin, category: "Space")
        precondition(downloaded.title == "Cloudscape" && downloaded.sourceURL == origin.absoluteString && downloaded.category == "Space", "Download attribution must survive import")
        let workshopDirectory = root.appendingPathComponent("123456789")
        try FileManager.default.createDirectory(at: workshopDirectory, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: source, to: workshopDirectory.appendingPathComponent("wallpaper.mp4"))
        try Data(#"{"type":"video","file":"wallpaper.mp4","title":"Workshop Fixture","workshopid":"123456789"}"#.utf8).write(to: workshopDirectory.appendingPathComponent("project.json"))
        let project = try WorkshopVideoProject.read(workshopDirectory)
        let workshopScene = try await model.importVideo(project.videoURL, title: project.title, sourceURL: project.sourceURL, category: "Imported")
        precondition(workshopScene.title == "Workshop Fixture" && workshopScene.sourceURL?.contains("123456789") == true, "Workshop project metadata and actual video must import together")
        let workshopCopy = model.videoURL(for: workshopScene)!
        let copyData = try Data(contentsOf: workshopCopy)
        let sourceData = try Data(contentsOf: source)
        precondition(copyData == sourceData, "Workshop import must copy the actual video, never its preview")
        model.remove(workshopScene)
        print("PASS: Workshop manifest and actual playable video import together with attribution")
        let reload = LibraryStore(directory: root)
        precondition(reload.state.imports.first?.sourceURL == origin.absoluteString, "Source page must survive restart")
        var old = try JSONSerialization.jsonObject(with: JSONEncoder().encode(reload.state)) as! [String:Any]
        var imports = old["imports"] as! [[String:Any]]
        imports[0].removeValue(forKey: "sourceURL")
        old["imports"] = imports
        let legacy = try JSONDecoder().decode(LibraryState.self, from: JSONSerialization.data(withJSONObject: old))
        precondition(legacy.imports[0].sourceURL == nil, "Older libraries must decode without the new field")
        print("PASS: downloaded title, Space category and source URL persist; old libraries remain compatible")
        let configuredRoot = root.appendingPathComponent("configured-library", isDirectory: true)
        try FileManager.default.createDirectory(at: configuredRoot, withIntermediateDirectories: true)
        try JSONEncoder().encode(LibraryState()).write(to: configuredRoot.appendingPathComponent("library.json"))
        let volumeInfo = try configuredRoot.resourceValues(forKeys: [.volumeURLKey, .volumeUUIDStringKey])
        let storage = LibraryStorage(directory: configuredRoot, volumeRoot: volumeInfo.allValues[.volumeURLKey] as! URL, volumeUUID: volumeInfo.volumeUUIDString!)
        let configuredStore = LibraryStore(storage: storage)
        let configuredVideo = try await configuredStore.importVideo(source, title: "Storage test", sourceURL: nil, category: "Imported")
        precondition(configuredStore.videoURL(for: configuredVideo)!.path.hasPrefix(configuredRoot.path + "/Videos/"), "Imports use the configured library volume")
        let incoming = try configuredStore.prepareIncomingDirectory()
        precondition(incoming.path == configuredRoot.appendingPathComponent("Incoming").path, "Downloads and extracted media use the same configured library")
        let repeatedIncoming = try configuredStore.prepareIncomingDirectory()
        precondition(repeatedIncoming == incoming, "Later downloads can reuse the existing Incoming directory")
        precondition(LibraryStore(storage: storage).state.imports.count == 1, "Configured library metadata persists on the selected volume")
        let metadata = configuredRoot.appendingPathComponent("library.json")
        let savedMetadata = try Data(contentsOf: metadata)
        try FileManager.default.removeItem(at: metadata)
        try FileManager.default.createDirectory(at: metadata, withIntermediateDirectories: false)
        var commitFailed = false
        do { _ = try await configuredStore.importVideo(source, title: "Failed commit", sourceURL: nil, category: "Imported") }
        catch { commitFailed = true }
        precondition(commitFailed && configuredStore.state.imports.count == 1, "A failed metadata commit must reject the import before publishing success")
        let managedFiles = try FileManager.default.contentsOfDirectory(atPath: configuredRoot.appendingPathComponent("Videos").path)
        precondition(managedFiles.count == 1, "A rejected import must clean up only its own copied video")
        try FileManager.default.removeItem(at: metadata)
        try savedMetadata.write(to: metadata)
        print("PASS: failed metadata commit rejects import without publishing or leaving an unmanaged copy")
        configuredStore.apply(configuredVideo)
        configuredStore.favourite(configuredVideo)
        let beforeRemoval = configuredStore.state
        let removalMetadata = try Data(contentsOf: metadata)
        let removalVideo = configuredStore.videoURL(for: configuredVideo)!
        try FileManager.default.removeItem(at: metadata)
        try FileManager.default.createDirectory(at: metadata, withIntermediateDirectories: false)
        configuredStore.remove(configuredVideo)
        precondition(configuredStore.error != nil, "A failed removal commit must report the error")
        precondition(FileManager.default.fileExists(atPath: removalVideo.path), "A failed removal commit must preserve the managed video")
        precondition(configuredStore.state.imports == beforeRemoval.imports && configuredStore.state.favourites == beforeRemoval.favourites && configuredStore.state.activeID == beforeRemoval.activeID && configuredStore.state.enabled == beforeRemoval.enabled, "A failed removal commit must preserve published library and playback state")
        try FileManager.default.removeItem(at: metadata)
        try removalMetadata.write(to: metadata)
        let removalReload = LibraryStore(storage: storage)
        precondition(removalReload.state.imports.contains(configuredVideo) && FileManager.default.fileExists(atPath: removalReload.videoURL(for: configuredVideo)!.path), "Reopening after a failed removal must retain playable media")
        configuredStore.error = nil
        configuredStore.remove(configuredVideo)
        precondition(configuredStore.error == nil && configuredStore.state.imports.isEmpty && !configuredStore.state.enabled && !FileManager.default.fileExists(atPath: removalVideo.path), "Successful removal must commit metadata and remove the owned copy")
        precondition(FileManager.default.fileExists(atPath: source.path), "Removal must keep the original video")
        print("PASS: failed removal preserves media and state across reopen; successful removal keeps original")
        try FileManager.default.removeItem(at: configuredRoot)
        var unavailable = false
        do { _ = try configuredStore.prepareIncomingDirectory() } catch { unavailable = true }
        configuredStore.state.fps = 60
        precondition(unavailable && !FileManager.default.fileExists(atPath: configuredRoot.path), "A disconnected/missing library must not be recreated by downloads or persistence")
        let fakeMount = root.appendingPathComponent("not-a-mounted-card")
        let offline = LibraryStore(storage: LibraryStorage(directory: fakeMount.appendingPathComponent("Library"), volumeRoot: fakeMount, volumeUUID: volumeInfo.volumeUUIDString!))
        await offline.importVideos([source])
        precondition(offline.error != nil && offline.state.imports.isEmpty && !FileManager.default.fileExists(atPath: fakeMount.path), "Unavailable configured storage must reject imports without creating a substitute on the internal volume")
        print("PASS: configured library holds videos, downloads and metadata; unavailable storage never creates a substitute")

    }
}
