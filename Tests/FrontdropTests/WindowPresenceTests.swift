import AppKit

final class WallpaperTestWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@main
struct WindowPresenceTests {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.finishLaunching()
        let presence = WindowPresenceController(application: app)
        presence.start()
        func window() -> NSWindow {
            let result = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 150), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            result.isReleasedWhenClosed = false
            result.identifier = NSUserInterfaceItemIdentifier(app.windows.contains(where: { $0.identifier?.rawValue == "library" }) ? "settings" : "library")
            app.activate(ignoringOtherApps: true)
            result.makeKeyAndOrderFront(nil)
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            return result
        }
        let library = window()
        let wallpaper = WallpaperTestWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 150), styleMask: [.borderless], backing: .buffered, defer: false)
        wallpaper.isReleasedWhenClosed = false
        wallpaper.orderFront(nil)
        var closeNotifications = 0
        let closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: library, queue: .main) { _ in closeNotifications += 1 }
        presence.stop()
        presence.start()
        library.performClose(nil)
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        assert(closeNotifications == 0, "X must hide and preserve the library instead of destroying its SwiftUI/browser state")
        NotificationCenter.default.removeObserver(closeObserver)
        assert(app.activationPolicy() == .accessory, "Closing the library must remove the Dock icon despite live wallpaper windows")
        assert(wallpaper.isVisible, "Closing library must preserve wallpaper windows")
        var reopened = false
        presence.reopenLibrary()
        reopened = library.isVisible
        assert(reopened && library.isVisible && app.activationPolicy() == .regular, "Reopening must restore a visible library and Dock presence")
        let settings = window()
        settings.identifier = NSUserInterfaceItemIdentifier("settings")
        library.close()
        assert(app.activationPolicy() == .regular, "Another visible settings window must remain accessible")
        settings.close()
        assert(app.activationPolicy() == .accessory, "Closing the final user window must hide the Dock icon")
        presence.stop()
        wallpaper.close()
        print("PASS: close-to-menu-bar, wallpaper preservation, reopen and settings window lifecycle")
    }
}
