import AppKit

@MainActor
final class WindowPresenceController: NSObject, NSWindowDelegate {
    let application: NSApplication
    private weak var libraryWindow: NSWindow?
    private weak var libraryDelegate: NSWindowDelegate?
    init(application: NSApplication) { self.application = application }
    func start() {
        NotificationCenter.default.addObserver(self, selector: #selector(userWindowWillClose(_:)), name: NSWindow.willCloseNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(windowBecameKey(_:)), name: NSWindow.didBecomeKeyNotification, object: nil)
        application.windows.forEach(rememberLibrary)
    }
    func stop() {
        NotificationCenter.default.removeObserver(self)
        if libraryWindow?.delegate === self { libraryWindow?.delegate = libraryDelegate }
    }
    private func rememberLibrary(_ window: NSWindow) {
        guard window.identifier?.rawValue == "library", window.delegate !== self else { return }
        libraryWindow = window
        libraryDelegate = window.delegate
        window.delegate = self
    }
    // SwiftUI still owns resizing, commands and the rest of the window lifecycle.
    override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || (libraryDelegate?.responds(to: selector) ?? false)
    }
    override func forwardingTarget(for selector: Selector!) -> Any? {
        libraryDelegate?.responds(to: selector) == true ? libraryDelegate : super.forwardingTarget(for: selector)
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender === libraryWindow else { return true }
        sender.orderOut(nil)
        hideDockIfNeeded(excluding: sender)
        return false
    }
    private func isUserWindow(_ window: NSWindow) -> Bool {
        window.canBecomeKey && window.styleMask.contains(.titled) && window.level == .normal
    }
    @objc private func userWindowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow, isUserWindow(closing) else { return }
        hideDockIfNeeded(excluding: closing)
    }
    private func hideDockIfNeeded(excluding closing: NSWindow) {
        let anotherWindow = application.windows.contains {
            $0 !== closing && isUserWindow($0) && ($0.isVisible || $0.isMiniaturized)
        }
        if !anotherWindow, application.activationPolicy() != .accessory { application.setActivationPolicy(.accessory) }
    }
    @objc private func windowBecameKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, isUserWindow(window) else { return }
        rememberLibrary(window)
        if application.activationPolicy() != .regular { application.setActivationPolicy(.regular) }
    }
    func reopenLibrary() {
        Self.showLibrary {
            // Wallpaper windows are always visible, so AppKit's hasVisibleWindows
            // flag cannot tell us whether the actual library is open.
            guard let window = libraryWindow ?? application.windows.first(where: { $0.identifier?.rawValue == "library" }) else { return }
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        }
    }
    static func showLibrary(_ open: () -> Void) {
        let application = NSApplication.shared
        if application.activationPolicy() != .regular { application.setActivationPolicy(.regular) }
        open()
        application.activate(ignoringOtherApps: true)
    }
}
