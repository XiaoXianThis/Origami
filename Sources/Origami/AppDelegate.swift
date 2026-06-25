import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static private(set) weak var shared: AppDelegate?

    private var window: NSWindow?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        NSApp.setActivationPolicy(.accessory)
        setupWindow()
        setupStatusItem()
        WindowOverlayManager.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        WindowOverlayManager.shared.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func setupWindow() {
        let contentView = NSHostingView(rootView: MainView())

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Origami"
        window.center()
        window.contentView = contentView
        // 关闭时仅隐藏，避免 window 被释放后 self.window 变成悬空指针
        window.isReleasedWhenClosed = false
        window.delegate = self
        applyTheme(to: window)

        self.window = window
    }

    func applyTheme() {
        applyTheme(to: window)
    }

    private func applyTheme(to window: NSWindow?) {
        window?.appearance = AppSettings.resolvedNSAppearance()
    }

    private func setupStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: "Origami")

        let menu = NSMenu()
        let showItem = NSMenuItem(title: "显示窗口", action: #selector(showWindow(_:)), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        self.statusItem = statusItem
    }

    @objc func showWindow(_ sender: Any?) {
        if window == nil {
            setupWindow()
        }
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }
}