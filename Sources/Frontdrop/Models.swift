import Foundation
import CoreGraphics

enum VideoFraming: String, Codable, CaseIterable, Identifiable {
    case fit = "Fit whole video"
    case fill = "Fill screen"
    var id: String { rawValue }
}

struct Wallpaper: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var title: String
    let subtitle: String
    let category: String
    let shader: Int?
    let filename: String?
    var sourceURL: String? = nil
    var videoFraming: VideoFraming? = nil
    var framing: VideoFraming { videoFraming ?? .fit }

    static let builtins: [Wallpaper] = [
        .init(id: "alpine", title: "First Light", subtitle: "Mist over an alpine lake", category: "Nature", shader: 6, filename: "nature.png"),
        .init(id: "last-train", title: "The Last Train", subtitle: "A quiet stop above the clouds", category: "Anime & Games", shader: 7, filename: "anime.png"),
        .init(id: "aurora", title: "Northern Lights", subtitle: "Slow ribbons in the polar sky", category: "Nature", shader: 0, filename: nil),
        .init(id: "silk", title: "Liquid Silk", subtitle: "Iridescent folds, endlessly flowing", category: "Abstract", shader: 1, filename: nil),
        .init(id: "tide", title: "Blue Hour", subtitle: "An ocean of luminous ripples", category: "Nature", shader: 2, filename: nil),
        .init(id: "orbit", title: "Event Horizon", subtitle: "A quiet journey through starlight", category: "Space", shader: 3, filename: nil),
        .init(id: "dunes", title: "Desert Bloom", subtitle: "Warm sculpted waves of colour", category: "Abstract", shader: 4, filename: nil),
        .init(id: "neon", title: "After Hours", subtitle: "A neon horizon in perpetual motion", category: "Anime & Games", shader: 5, filename: nil)
    ]
}

struct LibraryState: Codable {
    var imports: [Wallpaper] = []
    var favourites: Set<String> = []
    var activeID: String = "alpine"
    var enabled = false
    var target = "all"
    var manuallyPaused = false
    var pauseOnBattery = false
    var pauseInLowPower = true
    var pauseInFullscreen = true
    var fps = 30
    var rotationMinutes = 0
}

enum PauseReason: String {
    case manual = "Paused"
    case sleeping = "Display asleep"
    case locked = "Mac locked"
    case battery = "Paused on battery"
    case lowPower = "Low Power Mode"
    case fullscreen = "Fullscreen app"
}

struct PlaybackConditions {
    var manuallyPaused = false
    var isSleeping = false
    var isLocked = false
    var onBattery = false
    var lowPower = false
    var fullscreen = false
    var pauseOnBattery = false
    var pauseInLowPower = true
    var pauseInFullscreen = true

    var pauseReason: PauseReason? {
        if manuallyPaused { return .manual }
        if isSleeping { return .sleeping }
        if isLocked { return .locked }
        if onBattery && pauseOnBattery { return .battery }
        if lowPower && pauseInLowPower { return .lowPower }
        if fullscreen && pauseInFullscreen { return .fullscreen }
        return nil
    }
}

enum DisplaySelection {
    static func windowCoversDisplay(window: CGRect, display: CGRect, primaryMaxY: CGFloat) -> Bool {
        let cgDisplay = CGRect(x: display.minX, y: primaryMaxY-display.maxY, width: display.width, height: display.height)
        return abs(window.minX-cgDisplay.minX) < 3 && abs(window.minY-cgDisplay.minY) < 3
            && abs(window.width-cgDisplay.width) < 3 && abs(window.height-cgDisplay.height) < 3
    }

    static func resolve(target: String, available: [UInt32], main: UInt32?) -> [UInt32] {
        if target == "all" { return available }
        if let id = UInt32(target), available.contains(id) { return [id] }
        if let main, available.contains(main) { return [main] }
        return Array(available.prefix(1))
    }
}

enum AppResources {
    static func url(_ filename: String) -> URL? {
        #if SWIFT_PACKAGE
        return Bundle.module.url(forResource: filename, withExtension: nil, subdirectory: "Resources")
        #else
        return Bundle.main.url(forResource: filename, withExtension: nil)
        #endif
    }
}
