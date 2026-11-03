import AppKit
import AVFoundation
import Combine
import ServiceManagement
import UniformTypeIdentifiers

@MainActor
final class LibraryStore: ObservableObject {
    @Published var state: LibraryState { didSet { persist(); engine?.reconcile() } }
    @Published var selectedID: String
    @Published var error: String?
    @Published var importing = false
    @Published var thumbnails: [String: NSImage] = [:]
    @Published var status = "Wallpaper stopped"
    @Published var screens: [(id: String, name: String)] = []
    @Published var loginEnabled = SMAppService.mainApp.status == .enabled
    private(set) var engine: DesktopEngine?
    let directory: URL
    private let stateURL: URL
    private let storage: LibraryStorage?
    private var storageReady = false

    init(directory: URL? = nil, storage: LibraryStorage? = nil) {
        var configured: LibraryStorage?
        var configurationError: Error?
        if directory == nil {
            do { configured = try storage ?? LibraryStorage.configured() }
            catch { configurationError = error }
        }
        self.storage = configured
        let root = directory ?? configured?.directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Frontdrop", isDirectory: true)
        self.directory = root
        self.stateURL = root.appendingPathComponent("library.json")
        var loaded = LibraryState()
        var loadError: String?
        do {
            if let configurationError { throw configurationError }
            try configured?.requireAvailable()
            let videos = root.appendingPathComponent("Videos", isDirectory: true)
            if (try? videos.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) != true {
                try FileManager.default.createDirectory(at: videos, withIntermediateDirectories: configured == nil)
            }
            if FileManager.default.fileExists(atPath: stateURL.path) {
                loaded = try JSONDecoder().decode(LibraryState.self, from: Data(contentsOf: stateURL))
            } else if configured != nil {
                throw LibraryStorage.StorageError("The saved library file is missing at \(stateURL.path). Restore it before reopening Frontdrop.")
            }
            storageReady = true
        } catch { loadError = "The saved library could not be opened: \(error.localizedDescription). Your video files have been kept." }
        state = loaded
        selectedID = loaded.activeID
        error = loadError
        if !scenes.contains(where: { $0.id == selectedID }) { selectedID = Wallpaper.builtins[0].id }
    }

    var scenes: [Wallpaper] { Wallpaper.builtins + state.imports }
    var selected: Wallpaper { scenes.first(where: { $0.id == selectedID }) ?? Wallpaper.builtins[0] }
    var active: Wallpaper { scenes.first(where: { $0.id == state.activeID }) ?? Wallpaper.builtins[0] }
    func videoURL(for scene: Wallpaper) -> URL? {
        guard scene.shader == nil, let filename = scene.filename else { return nil }
        // Only managed filenames are accepted from persisted state.
        guard filename == URL(fileURLWithPath: filename).lastPathComponent else { return nil }
        return directory.appendingPathComponent("Videos").appendingPathComponent(filename)
    }
    func start() {
        guard engine == nil else { return }
        engine = DesktopEngine(store: self)
        engine?.start()
        Task { await loadThumbnails() }
    }
    func requireStorageAvailable() throws {
        guard storageReady else { throw LibraryStorage.StorageError("The wallpaper library is unavailable. Reconnect its drive and reopen Frontdrop; downloads will not use internal storage.") }
        try storage?.requireAvailable()
    }
    func prepareIncomingDirectory() throws -> URL {
        try requireStorageAvailable()
        let incoming = directory.appendingPathComponent("Incoming", isDirectory: true)
        if (try? incoming.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) != true {
            try FileManager.default.createDirectory(at: incoming, withIntermediateDirectories: storage == nil)
        }
        return incoming
    }
    private func persist() {
        do { try save(state) }
        catch { self.error = "Could not save your library: \(error.localizedDescription)" }
    }
    private func save(_ next: LibraryState) throws {
        try requireStorageAvailable()
        try JSONEncoder().encode(next).write(to: stateURL, options: .atomic)
    }
    func apply(_ scene: Wallpaper? = nil) {
        var next = state
        next.activeID = (scene ?? selected).id
        next.enabled = true
        next.manuallyPaused = false
        state = next
    }
    func setVideoFraming(_ framing: VideoFraming, for scene: Wallpaper) {
        guard scene.shader == nil, let index = state.imports.firstIndex(where: { $0.id == scene.id }), state.imports[index].framing != framing else { return }
        state.imports[index].videoFraming = framing
    }
    func stop() { state.enabled = false }
    func togglePause() { state.manuallyPaused.toggle() }
    func favourite(_ scene: Wallpaper) {
        if state.favourites.contains(scene.id) { state.favourites.remove(scene.id) }
        else { state.favourites.insert(scene.id) }
    }
    func nextScene() {
        let preferred = scenes.filter { state.favourites.contains($0.id) }
        let candidates = preferred.isEmpty ? scenes : preferred
        guard !candidates.isEmpty else { return }
        let next = ((candidates.firstIndex(where: { $0.id == state.activeID }) ?? -1)+1)%candidates.count
        apply(candidates[next])
    }
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginEnabled = SMAppService.mainApp.status == .enabled
            if enabled && !loginEnabled { error = "Allow Frontdrop in System Settings → General → Login Items & Extensions." }
        } catch { self.error = "Could not change Start at Login: \(error.localizedDescription)" }
    }
    @discardableResult
    func chooseVideos() -> Bool {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.prompt = "Add Wallpapers"
        panel.message = "Choose MP4, MOV, or other playable video files from your Mac."
        guard panel.runModal() == .OK else { return false }
        return addVideos(panel.urls)
    }
    @discardableResult
    func addVideos(_ urls: [URL]) -> Bool {
        guard !importing, !urls.isEmpty else { return false }
        var entries: [(url: URL, title: String?)] = []
        for (index, url) in urls.enumerated() {
            let alert = NSAlert()
            alert.messageText = "Name your wallpaper"
            alert.informativeText = "\(url.lastPathComponent) will be copied into your Frontdrop library.\(urls.count > 1 ? " (\(index + 1) of \(urls.count))" : "")"
            alert.addButton(withTitle: "Add Wallpaper")
            alert.addButton(withTitle: "Cancel")
            let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 330, height: 24))
            field.stringValue = url.deletingPathExtension().lastPathComponent
            field.placeholderString = "Wallpaper name"
            alert.accessoryView = field
            alert.window.initialFirstResponder = field
            guard alert.runModal() == .alertFirstButtonReturn else { return false }
            entries.append((url: url, title: field.stringValue))
        }
        Task { await importVideos(entries) }
        return true
    }
    func chooseWorkshopVideo(completion: @escaping (Wallpaper) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.prompt = "Import Workshop Video"
        panel.message = "Select one downloaded Video wallpaper's folder containing project.json. Scene and Web projects cannot play in Frontdrop."
        guard panel.runModal() == .OK, let directory = panel.url else { return }
        Task {
            importing = true
            defer { importing = false }
            do {
                let project = try await Task.detached(priority: .userInitiated) { try WorkshopVideoProject.read(directory) }.value
                let scene = try await importVideo(project.videoURL, title: project.title, sourceURL: project.sourceURL, category: "Imported")
                completion(scene)
            } catch { self.error = "Workshop import failed: \(error.localizedDescription)" }
        }
    }
    func importVideos(_ urls: [URL]) async {
        await importVideos(urls.map { (url: $0, title: nil) })
    }
    func importVideos(_ entries: [(url: URL, title: String?)]) async {
        importing = true
        defer { importing = false }
        for entry in entries {
            do {
                let trimmed = entry.title?.trimmingCharacters(in: .whitespacesAndNewlines)
                _ = try await importVideo(entry.url, title: trimmed?.isEmpty == false ? trimmed : nil, sourceURL: nil, category: "Imported")
            } catch { self.error = "Import failed: \(error.localizedDescription)" }
        }
    }
    @discardableResult
    func importVideo(_ url: URL, title: String?, sourceURL: URL?, category: String) async throws -> Wallpaper {
        try requireStorageAvailable()
        let asset = AVURLAsset(url: url)
        let playable = try await asset.load(.isPlayable)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard playable && !tracks.isEmpty else { throw RenderError.unavailable("This file has no playable video track. Choose an H.264 or HEVC MP4/MOV download.") }
        let id = UUID().uuidString
        let filename = id + "." + url.pathExtension.lowercased()
        let destination = directory.appendingPathComponent("Videos").appendingPathComponent(filename)
        try requireStorageAvailable()
        try await Task.detached(priority: .userInitiated) { try FileManager.default.copyItem(at: url, to: destination) }.value
        let scene = Wallpaper(id: id, title: title ?? url.deletingPathExtension().lastPathComponent, subtitle: sourceURL?.host.map { "Downloaded from " + $0 } ?? "Your video · plays silently on repeat", category: category, shader: nil, filename: filename, sourceURL: sourceURL?.absoluteString)
        var next = state
        next.imports.append(scene)
        do {
            // Commit before publishing success; the card may have gone away during the copy.
            try save(next)
        } catch {
            let commitError = error
            do { try requireStorageAvailable(); try FileManager.default.removeItem(at: destination) }
            catch { /* Never touch a replacement or unavailable volume to clean up. */ }
            throw commitError
        }
        state = next
        selectedID = id
        await loadThumbnail(scene)
        return scene
    }
    func remove(_ scene: Wallpaper) {
        guard scene.shader == nil, let url = videoURL(for: scene) else { return }
        do {
            try requireStorageAvailable()
            var next = state
            next.imports.removeAll { $0.id == scene.id }
            next.favourites.remove(scene.id)
            if next.activeID == scene.id { next.activeID = Wallpaper.builtins[0].id; next.enabled = false }
            // A failed metadata commit must leave the video and published state intact.
            try save(next)
            state = next
            thumbnails[scene.id] = nil
            if selectedID == scene.id { selectedID = Wallpaper.builtins[0].id }
            do {
                if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            } catch { self.error = "The video was removed from your library, but its file could not be deleted: \(error.localizedDescription)" }
        } catch { self.error = "Could not remove this video: \(error.localizedDescription)" }
    }
    func loadThumbnails() async { for scene in scenes { await loadThumbnail(scene); await Task.yield() } }
    private func loadThumbnail(_ scene: Wallpaper) async {
        guard thumbnails[scene.id] == nil else { return }
        do {
            if scene.shader != nil {
                thumbnails[scene.id] = try await Task.detached(priority: .utility) {
                    if let url = AppResources.url("preview-" + scene.id + ".png"), let image = NSImage(contentsOf: url) { return image }
                    return try SceneGPU.shared.get().thumbnail(for: scene)
                }.value
            }
            else if let url = videoURL(for: scene) {
                let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 600, height: 375)
                let (image, _) = try await generator.image(at: .zero)
                thumbnails[scene.id] = NSImage(cgImage: image, size: .zero)
            }
        } catch { /* A missing thumbnail does not prevent browsing or show repeated alerts. Playback reports actionable errors. */ }
    }
}
