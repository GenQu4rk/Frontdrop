import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var onTerminate: (() -> Void)?
    let windowPresence = WindowPresenceController(application: .shared)
    func applicationDidFinishLaunching(_ notification: Notification) { windowPresence.start() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { windowPresence.stop(); Self.onTerminate?() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        windowPresence.reopenLibrary()
        return false
    }
}

@main
struct FrontdropApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = LibraryStore()
    init() {
        if CommandLine.arguments.contains("--render-previews") {
            do { try RendererVerification.run(); exit(0) }
            catch { fputs("Renderer verification failed: \(error)\n",stderr); exit(1) }
        }
    }
    var body: some Scene {
        Window("Frontdrop",id: "library") {
            LibraryView().environmentObject(model).preferredColorScheme(.dark)
                .onAppear { AppDelegate.onTerminate = { model.engine?.shutdown() } }
        }
        .defaultSize(width: 1120,height: 820)
        .commands { CommandGroup(after: .newItem) { Button("Import Video…") { model.chooseVideos() }.keyboardShortcut("o") } }
        MenuBarExtra {
            MenuControls().environmentObject(model)
        } label: {
            Image(nsImage: BrandAssets.menuBar).accessibilityLabel("Frontdrop")
        }
        Settings { PlaybackSettings().environmentObject(model) }
    }
}

enum BrandAssets {
    static let logo = Bundle.main.url(forResource: "FrontdropLogoTransparent", withExtension: "png")
        .flatMap(NSImage.init(contentsOf:)) ?? NSImage(size: NSSize(width: 32, height: 32))
    static let menuBar: NSImage = {
        let image = Bundle.main.url(forResource: "FrontdropMenuTemplate", withExtension: "png")
            .flatMap(NSImage.init(contentsOf:)) ?? NSImage(size: NSSize(width: 18, height: 18))
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }()
}

struct MenuControls: View {
    @EnvironmentObject var model: LibraryStore
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Text(model.state.enabled ? model.active.title : "Frontdrop")
        Text(model.status)
        Divider()
        Button("Open Frontdrop") {
            WindowPresenceController.showLibrary { openWindow(id: "library") }
        }
        if model.state.enabled {
            Button(model.state.manuallyPaused ? "Resume Wallpaper" : "Pause Wallpaper") { model.togglePause() }
            Button("Next Wallpaper") { model.nextScene() }
            Button("Stop Wallpaper") { model.stop() }
        } else { Button("Start Wallpaper") { model.apply(model.active) } }
        Divider()
        SettingsLink { Text("Settings…") }
        Divider()
        Button("Quit Frontdrop") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
    }
}
