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
        HotKeyMonitor.shared.register(choice: store.settings.hotKey)
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stopMonitoring()
    }

    @objc private func togglePanel() { panelController?.toggle() }
    @objc private func toggleRecording() {
        store.settings.isPaused ? store.resumeRecording() : store.pause(for: .indefinitely)
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
        if store.settings.isPaused {
            let resume = NSMenuItem(title: "Resume Recording", action: #selector(toggleRecording), keyEquivalent: "")
            resume.target = self; menu.addItem(resume)
        } else {
            let pauseMenu = NSMenu()
            for duration in PauseDuration.allCases {
                let item = NSMenuItem(title: duration.title, action: #selector(pauseRecording(_:)), keyEquivalent: "")
                item.representedObject = duration.rawValue; item.target = self; pauseMenu.addItem(item)
            }
            let pause = NSMenuItem(title: "Pause Recording", action: nil, keyEquivalent: "")
            pause.submenu = pauseMenu; menu.addItem(pause)
        }
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let quit = NSMenuItem(title: "Quit PasteX", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem?.menu = menu
        statusItem?.button?.image = NSImage(systemSymbolName: store.settings.isPaused ? "pause.circle" : "clipboard", accessibilityDescription: "PasteX")
    }

    @objc private func pauseRecording(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? Int, let duration = PauseDuration(rawValue: seconds) else { return }
        store.pause(for: duration); refreshMenu()
    }
}
