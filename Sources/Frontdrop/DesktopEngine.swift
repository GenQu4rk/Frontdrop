import AppKit
import Combine
import IOKit.ps

final class DesktopWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class DesktopEngine {
    private weak var store: LibraryStore?
    private var windows: [DesktopWindow] = []
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var timer: Timer?
    private var signature = ""
    private var sleeping = false
    private var locked = false
    private var pauseReason: PauseReason?
    private var lastRotation = Date()
    private var rotationSetting = 0

    init(store: LibraryStore) { self.store = store }
    func start() {
        observe(NSApplication.didChangeScreenParametersNotification, center: .default) { [weak self] in self?.reconcile() }
        let center = NSWorkspace.shared.notificationCenter
        observe(NSWorkspace.screensDidSleepNotification, center: center) { [weak self] in self?.sleeping = true; self?.updatePlayback() }
        observe(NSWorkspace.screensDidWakeNotification, center: center) { [weak self] in self?.sleeping = false; self?.updatePlayback() }
        observe(NSWorkspace.willSleepNotification, center: center) { [weak self] in self?.sleeping = true; self?.updatePlayback() }
        observe(NSWorkspace.didWakeNotification, center: center) { [weak self] in self?.sleeping = false; self?.signature = ""; self?.reconcile() }
        observe(NSWorkspace.sessionDidResignActiveNotification, center: center) { [weak self] in self?.locked = true; self?.updatePlayback() }
        observe(NSWorkspace.sessionDidBecomeActiveNotification, center: center) { [weak self] in self?.locked = false; self?.updatePlayback() }
        observe(Notification.Name("com.apple.screenIsLocked"), center: DistributedNotificationCenter.default()) { [weak self] in self?.locked = true; self?.updatePlayback() }
        observe(Notification.Name("com.apple.screenIsUnlocked"), center: DistributedNotificationCenter.default()) { [weak self] in self?.locked = false; self?.updatePlayback() }
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        reconcile()
    }
    private func observe(_ name: Notification.Name, center: NotificationCenter, action: @escaping () -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in action() }
        observers.append((center,token))
    }
    func reconcile() {
        guard let store else { return }
        let screens = NSScreen.screens.map { (String(Self.id($0)), $0.localizedName) }
        if !store.screens.elementsEqual(screens, by: { $0.id == $1.0 && $0.name == $1.1 }) { store.screens = screens }
        if store.state.rotationMinutes != rotationSetting {
            rotationSetting = store.state.rotationMinutes
            lastRotation = Date()
        }
        guard store.state.enabled else {
            tearDown()
            signature = ""
            if store.status != "Wallpaper stopped" { store.status = "Wallpaper stopped" }
            return
        }
        let scene = store.active
        let availableScreens = NSScreen.screens
        let ids = DisplaySelection.resolve(target: store.state.target, available: availableScreens.map(Self.id), main: availableScreens.first.map(Self.id))
        let targetScreens = availableScreens.filter { ids.contains(Self.id($0)) }
        // Dock visibility changes visibleFrame and sends a screen notification.
        // Only actual display/geometry changes should rebuild desktop players.
        let layout = targetScreens.map { "\(Self.id($0)):\(NSStringFromRect($0.frame)):\($0.backingScaleFactor)" }.sorted().joined(separator: "|")
        let nextSignature = scene.id + ":" + store.state.target + ":" + layout
        if nextSignature != signature {
            tearDown()
            do {
                for screen in targetScreens {
                    let view: NSView
                    if scene.shader != nil { view = try AnimatedSceneView(scene: scene) }
                    else if let url = store.videoURL(for: scene), FileManager.default.fileExists(atPath: url.path) { view = VideoSceneView(url: url, framing: scene.framing) }
                    else { throw RenderError.unavailable("The video is missing. Import it again to use it as a wallpaper.") }
                    let onError: (Error) -> Void = { [weak self, weak store] error in
                        store?.error = "Wallpaper playback failed: \(error.localizedDescription)"
                        store?.stop()
                        self?.tearDown()
                    }
                    (view as? AnimatedSceneView)?.onError = onError
                    (view as? VideoSceneView)?.onError = onError
                    let window = DesktopWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false, screen: screen)
                    window.setFrame(screen.frame, display: false)
                    window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow))+1)
                    window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
                    window.ignoresMouseEvents = true
                    window.isReleasedWhenClosed = false
                    window.isOpaque = true
                    window.backgroundColor = .black
                    window.hasShadow = false
                    window.hidesOnDeactivate = false
                    window.title = "Frontdrop Wallpaper — \(screen.localizedName)"
                    window.contentView = view
                    windows.append(window)
                    window.orderFrontRegardless()
                }
                signature = nextSignature
                lastRotation = Date()
            } catch {
                tearDown()
                store.error = error.localizedDescription
                store.state.enabled = false
                return
            }
        }
        updatePlayback()
    }
    private func updatePlayback() {
        guard let store, store.state.enabled else { return }
        let state = store.state
        var conditions = PlaybackConditions()
        conditions.manuallyPaused = state.manuallyPaused
        conditions.isSleeping = sleeping
        conditions.isLocked = locked
        conditions.onBattery = Self.onBattery
        conditions.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        conditions.fullscreen = state.pauseInFullscreen && Self.fullscreenApp(on: windows.map(\.frame))
        conditions.pauseOnBattery = state.pauseOnBattery
        conditions.pauseInLowPower = state.pauseInLowPower
        conditions.pauseInFullscreen = state.pauseInFullscreen
        pauseReason = conditions.pauseReason
        let playing = pauseReason == nil
        for window in windows {
            (window.contentView as? AnimatedSceneView)?.setPlaying(playing, fps: state.fps)
            if let video = window.contentView as? VideoSceneView {
                video.setFraming(store.active.framing)
                video.setPlaying(playing)
            }
        }
        let status = windows.isEmpty ? "No connected display" : (pauseReason?.rawValue ?? "Playing on \(windows.count == 1 ? "1 display" : "\(windows.count) displays")")
        if store.status != status { store.status = status }
    }
    private func tick() {
        updatePlayback()
        guard let store, store.state.enabled, pauseReason == nil, rotationSetting > 0 else { lastRotation = Date(); return }
        if Date().timeIntervalSince(lastRotation) >= Double(rotationSetting*60) { store.nextScene() }
    }
    private func tearDown() {
        for window in windows {
            (window.contentView as? AnimatedSceneView)?.setPlaying(false, fps: 30)
            (window.contentView as? VideoSceneView)?.setPlaying(false)
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
    }
    func shutdown() {
        timer?.invalidate()
        timer = nil
        observers.forEach { $0.0.removeObserver($0.1) }
        observers.removeAll()
        tearDown()
    }
    private static func id(_ screen: NSScreen) -> UInt32 { (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0 }
    private static var onBattery: Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(), let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() else { return false }
        return (type as String) == kIOPSBatteryPowerValue
    }
    private static func fullscreenApp(on frames: [CGRect]) -> Bool {
        guard let front = NSWorkspace.shared.frontmostApplication, front.bundleIdentifier != "com.apple.finder", front.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return false }
        return list.contains { info in
            guard info[kCGWindowOwnerPID as String] as? pid_t == front.processIdentifier,
                  info[kCGWindowLayer as String] as? Int == 0,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return false }
            return frames.contains { DisplaySelection.windowCoversDisplay(window: rect, display: $0, primaryMaxY: NSScreen.screens.first?.frame.maxY ?? 0) }
        }
    }
}
