import AppKit
import AVFoundation

@main struct PreviewTests {
    @MainActor static func main() {
        Task { @MainActor in
            do { try await run(); exit(0) }
            catch { fputs("Preview check failed: \(error)\n", stderr); exit(1) }
        }
        NSApplication.shared.run()
    }
    @MainActor static func run() async throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let host = ScenePreviewHost()
        let window = NSWindow(contentRect: NSRect(x: 20, y: 20, width: 400, height: 250), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFrontRegardless()
        defer { window.close() }
        let image = NSImage(size: NSSize(width: 600, height: 375))
        let start = CACurrentMediaTime()
        host.show(scene: Wallpaper.builtins[0], url: nil, thumbnail: image, playing: true, fps: 30, onError: { fatalError($0.localizedDescription) })
        precondition(host.poster.image === image, "Selection must show its thumbnail before GPU preparation finishes")
        let elapsed = (CACurrentMediaTime()-start)*1000
        precondition(elapsed < 100, "Selecting a scene must not synchronously prepare Metal or read media")
        print("PASS: immediate poster selection \(String(format: "%.2f", elapsed)) ms")
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        let video = Wallpaper(id: "preview-test", title: "Test", subtitle: "", category: "Imported", shader: nil, filename: url.lastPathComponent)
        host.show(scene: video, url: url, thumbnail: image, playing: true, fps: 30, onError: { fatalError($0.localizedDescription) })
        let readyDeadline = Date().addingTimeInterval(5)
        while Date() < readyDeadline {
            if let view = host.renderer as? VideoSceneView, view.player.currentTime().seconds > 0 && !view.isHidden { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        precondition(host.sceneID == video.id && host.renderer is VideoSceneView, "A slow earlier shader preparation must not replace the latest selected video")
        let videoView = host.renderer as! VideoSceneView
        precondition(videoView.player.currentTime().seconds > 0 && !videoView.isHidden, "Prepared video must replace its poster and actually play in a visible window")
        precondition(videoView.playerLayer.videoGravity == .resizeAspect, "Video preview defaults to the complete frame")
        var filled = video
        filled.videoFraming = .fill
        host.show(scene: filled, url: url, thumbnail: image, playing: true, fps: 30, onError: { fatalError($0.localizedDescription) })
        precondition(host.renderer === videoView && videoView.playerLayer.videoGravity == .resizeAspectFill, "Same-video framing changes should update the existing preview")
        host.show(scene: video, url: url, thumbnail: image, playing: true, fps: 30, onError: { fatalError($0.localizedDescription) })
        precondition(videoView.playerLayer.videoGravity == .resizeAspect, "Fit must be restored without a stale preview renderer")
        print("PASS: preview framing follows same-video changes without rebuilding the decoder")
        window.orderOut(nil)
        let hiddenDeadline = Date().addingTimeInterval(3)
        while videoView.player.rate != 0 && Date() < hiddenDeadline { try await Task.sleep(nanoseconds: 20_000_000) }
        precondition(videoView.player.rate == 0, "Hiding the library must pause its preview")
        host.stop()
        precondition((host.renderer as? VideoSceneView)?.player.rate == 0, "Hiding/removing the preview must pause its decoder")
        print("PASS: latest selection wins, visible video plays, hidden/removed previews pause")
    }
}
