import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = ClipboardStore()
    private var statusItem: NSStatusItem?
    private var panelController: PanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        store.startMonitoring()
        panelController = PanelController(store: store)
        setupStatusItem()
        HotKeyMonitor.shared.onPress = { [weak self] in self?.panelController?.toggle() }
        HotKeyMonitor.shared.register()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stopMonitoring()
    }

    @objc private func togglePanel() { panelController?.toggle() }
    @objc private func toggleRecording() {
        store.settings.isRecordingPaused.toggle()
        refreshMenu()
    }
    @objc private func showSettings() { panelController?.showSettings() }
    @objc private func quit() { NSApp.terminate(nil) }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "PasteX")
        item.button?.toolTip = "PasteX — Option-Space"
        statusItem = item
        refreshMenu()
    }

    private func refreshMenu() {
        let menu = NSMenu()
        let open = NSMenuItem(title: "Open PasteX", action: #selector(togglePanel), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        let paused = NSMenuItem(title: store.settings.isRecordingPaused ? "Resume Recording" : "Pause Recording", action: #selector(toggleRecording), keyEquivalent: "")
        paused.target = self
        menu.addItem(paused)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let quit = NSMenuItem(title: "Quit PasteX", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem?.menu = menu
        statusItem?.button?.image = NSImage(systemSymbolName: store.settings.isRecordingPaused ? "pause.circle" : "clipboard", accessibilityDescription: "PasteX")
    }
}
