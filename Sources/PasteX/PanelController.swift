import AppKit
import SwiftUI

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private enum PreferenceKey { static let historyFrame = "PasteX.historyPanel.frame" }
    private let store: ClipboardStore
    private var historyPanel: NSPanel?
    private var settingsPanel: NSPanel?
    private var pasteTarget: NSRunningApplication?
    private var isHistoryPresented = false

    init(store: ClipboardStore) {
        self.store = store
    }

    func toggle() {
        if historyPanel?.isVisible == true { hideHistory() } else { showHistory() }
    }

    func showHistory() {
        pasteTarget = NSWorkspace.shared.frontmostApplication
        let panel = makeHistoryPanelIfNeeded()
        if let savedFrame = savedHistoryFrame() {
            panel.setFrame(savedFrame, display: false)
        } else if store.settings.quickMenuNearCursor, let point = focusedInputPoint() {
            let screen = NSScreen.screens.first { $0.visibleFrame.contains(point) } ?? NSScreen.main
            let visible = screen?.visibleFrame ?? .zero
            let origin = NSPoint(x: min(max(point.x, visible.minX), visible.maxX - panel.frame.width), y: min(max(point.y - panel.frame.height - 12, visible.minY), visible.maxY - panel.frame.height))
            panel.setFrameOrigin(origin)
        } else {
            panel.center()
        }
        isHistoryPresented = true
        panel.orderFront(nil)
        panel.makeKey()
        NotificationCenter.default.post(name: .pasteXHistoryPresentation, object: true)
        NotificationCenter.default.post(name: .pasteXFocusSearch, object: nil)
    }

    func hideHistory() {
        guard let historyPanel else { return }
        isHistoryPresented = false
        NotificationCenter.default.post(name: .pasteXHistoryPresentation, object: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self, weak historyPanel] in
            guard self?.isHistoryPresented == false else { return }
            historyPanel?.orderOut(nil)
        }
    }

    func showSettings() {
        hideHistory()
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
        hideHistory()
        store.paste(item, into: pasteTarget, textOverride: textOverride)
    }

    func windowDidResignKey(_ notification: Notification) {
        guard let historyPanel, historyPanel.isVisible, settingsPanel?.isKeyWindow != true else { return }
        hideHistory()
    }

    func windowDidMove(_ notification: Notification) { persistHistoryFrame() }
    func windowDidResize(_ notification: Notification) { persistHistoryFrame() }

    private func makeHistoryPanelIfNeeded() -> NSPanel {
        if let historyPanel { return historyPanel }
        let panel = NSPanel(
            contentRect: savedHistoryFrame() ?? NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "PasteX Clipboard History"
        panel.titleVisibility = .hidden
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.animationBehavior = .utilityWindow
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: FloatingHistorySurface {
            ClipboardPanelView(store: store, onPaste: { [weak self] item in self?.paste(item) }, onPasteText: { [weak self] item, text in self?.paste(item, textOverride: text) }, onSettings: { [weak self] in self?.showSettings() }, onClose: { [weak self] in self?.hideHistory() })
        })
        self.historyPanel = panel
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

    private func savedHistoryFrame() -> NSRect? {
        guard let value = UserDefaults.standard.string(forKey: PreferenceKey.historyFrame) else { return nil }
        let frame = NSRectFromString(value)
        return frame.width > 0 && frame.height > 0 ? frame : nil
    }

    private func persistHistoryFrame() {
        guard let historyPanel else { return }
        UserDefaults.standard.set(NSStringFromRect(historyPanel.frame), forKey: PreferenceKey.historyFrame)
    }
}

extension Notification.Name {
    static let pasteXFocusSearch = Notification.Name("pasteXFocusSearch")
    static let pasteXHistoryPresentation = Notification.Name("pasteXHistoryPresentation")
}
