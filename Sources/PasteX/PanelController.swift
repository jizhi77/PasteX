import AppKit
import SwiftUI

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let store: ClipboardStore
    private var panel: NSPanel?
    private var settingsPanel: NSPanel?
    private var pasteTarget: NSRunningApplication?

    init(store: ClipboardStore) {
        self.store = store
    }

    func toggle() {
        if panel?.isVisible == true { hide() } else { show() }
    }

    func show() {
        pasteTarget = NSWorkspace.shared.frontmostApplication
        let panel = makePanelIfNeeded()
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        NotificationCenter.default.post(name: .pasteXFocusSearch, object: nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func showSettings() {
        let panel: NSPanel
        if let settingsPanel { panel = settingsPanel }
        else {
            panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 400),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.title = "PasteX Settings"
            panel.isReleasedWhenClosed = false
            panel.contentView = NSHostingView(rootView: SettingsView(store: store))
            settingsPanel = panel
        }
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func paste(_ item: ClipboardItem) {
        hide()
        store.paste(item, into: pasteTarget)
    }

    func windowDidResignKey(_ notification: Notification) {
        guard let panel, panel.isVisible, settingsPanel?.isKeyWindow != true else { return }
        panel.orderOut(nil)
    }

    private func makePanelIfNeeded() -> NSPanel {
        if let panel { return panel }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 540),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: ClipboardPanelView(store: store, onPaste: { [weak self] item in self?.paste(item) }, onSettings: { [weak self] in self?.showSettings() }, onClose: { [weak self] in self?.hide() }))
        self.panel = panel
        return panel
    }
}

extension Notification.Name {
    static let pasteXFocusSearch = Notification.Name("pasteXFocusSearch")
}
