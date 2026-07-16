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
        if store.settings.quickMenuNearCursor, let point = focusedInputPoint() {
            let screen = NSScreen.screens.first { $0.visibleFrame.contains(point) } ?? NSScreen.main
            let visible = screen?.visibleFrame ?? .zero
            let origin = NSPoint(x: min(max(point.x, visible.minX), visible.maxX - panel.frame.width), y: min(max(point.y - panel.frame.height - 12, visible.minY), visible.maxY - panel.frame.height))
            panel.setFrameOrigin(origin)
        } else {
            panel.center()
        }
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

    func paste(_ item: ClipboardItem, textOverride: String? = nil) {
        hide()
        store.paste(item, into: pasteTarget, textOverride: textOverride)
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
        panel.contentView = NSHostingView(rootView: ClipboardPanelView(store: store, onPaste: { [weak self] item in self?.paste(item) }, onPasteText: { [weak self] item, text in self?.paste(item, textOverride: text) }, onSettings: { [weak self] in self?.showSettings() }, onClose: { [weak self] in self?.hide() }))
        self.panel = panel
        return panel
    }

    private func focusedInputPoint() -> CGPoint? {
        guard AXIsProcessTrusted() else { return nil }
        let system = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success,
              let focusedValue, CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else { return nil }
        let focused = unsafeDowncast(focusedValue, to: AXUIElement.self)
        var pointValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focused, kAXPositionAttribute as CFString, &pointValue) == .success,
              let pointValue, CFGetTypeID(pointValue) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(unsafeDowncast(pointValue, to: AXValue.self), .cgPoint, &point) else { return nil }
        return point
    }
}

extension Notification.Name {
    static let pasteXFocusSearch = Notification.Name("pasteXFocusSearch")
}
