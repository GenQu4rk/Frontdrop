import Foundation
import CoreGraphics

@main
struct PolicyTests {
    static func main() throws {
        var checks = 0
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            guard condition() else { fatalError(message) }
            checks += 1
        }
        var input = PlaybackConditions()
        expect(input.pauseReason == nil, "Default conditions should play")
        input.isLocked = true
        expect(input.pauseReason == .locked, "Lock pauses playback")
        input.isSleeping = true
        expect(input.pauseReason == .sleeping, "Sleep takes precedence")
        input.manuallyPaused = true
        expect(input.pauseReason == .manual, "Manual pause persists across wake")
        input = PlaybackConditions()
        input.onBattery = true
        expect(input.pauseReason == nil, "Battery playback allowed by default")
        input.pauseOnBattery = true
        expect(input.pauseReason == .battery, "Battery preference respected")
        input.pauseOnBattery = false
        input.lowPower = true
        expect(input.pauseReason == .lowPower, "Low power pauses by default")
        input.pauseInLowPower = false
        expect(input.pauseReason == nil, "Low power preference respected")
        input.fullscreen = true
        expect(input.pauseReason == .fullscreen, "Fullscreen pauses")
        input.pauseInFullscreen = false
        expect(input.pauseReason == nil, "Fullscreen preference respected")
        expect(DisplaySelection.resolve(target: "all", available: [10,20], main: 20) == [10,20], "All displays")
        expect(DisplaySelection.resolve(target: "10", available: [10,20], main: 20) == [10], "Specific display")
        expect(DisplaySelection.resolve(target: "99", available: [10,20], main: 20) == [20], "Disconnected display fallback")
        expect(DisplaySelection.resolve(target: "main", available: [], main: nil).isEmpty, "Headless has no display")
        let mainDisplay = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let otherDisplay = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        expect(DisplaySelection.windowCoversDisplay(window: mainDisplay, display: mainDisplay, primaryMaxY: 1080), "Fullscreen on target display")
        expect(!DisplaySelection.windowCoversDisplay(window: otherDisplay, display: mainDisplay, primaryMaxY: 1080), "Equal-sized untargeted display must not pause target")
        let upperDisplay = CGRect(x: 0, y: 1080, width: 1920, height: 1080)
        let upperWindow = CGRect(x: 0, y: -1080, width: 1920, height: 1080)
        expect(DisplaySelection.windowCoversDisplay(window: upperWindow, display: upperDisplay, primaryMaxY: 1080), "AppKit and CG display coordinates convert correctly")
        var state = LibraryState()
        let video = Wallpaper(id: "test", title: "Rain", subtitle: "Local video", category: "Imported", shader: nil, filename: "test.mov")
        state.imports = [video]
        state.favourites = [video.id]
        state.activeID = video.id
        state.enabled = true
        let restored = try JSONDecoder().decode(LibraryState.self, from: JSONEncoder().encode(state))
        expect(restored.imports == [video], "Imported video survives restart")
        expect(restored.favourites == [video.id], "Favourite survives restart")
        expect(restored.activeID == video.id && restored.enabled, "Active wallpaper survives restart")
        let legacyJSON = #"{"id":"old","title":"Wide scene","subtitle":"","category":"Imported","shader":null,"filename":"old.mp4"}"#
        let legacyVideo = try JSONDecoder().decode(Wallpaper.self, from: Data(legacyJSON.utf8))
        expect(legacyVideo.framing == .fit, "Existing videos should show the complete frame without requiring library migration")
        var framed = video
        framed.videoFraming = .fill
        let framedData = try JSONEncoder().encode(framed)
        let framedAgain = try JSONDecoder().decode(Wallpaper.self, from: framedData)
        expect(framedAgain.framing == .fill, "An explicit per-wallpaper Fill preference must survive restart")
        expect(video.framing == .fit, "New video defaults must not crop the edges")
        print("PASS: \(checks) playback, display, and persistence checks")
    }
}
