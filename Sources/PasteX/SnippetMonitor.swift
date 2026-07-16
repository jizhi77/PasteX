import AppKit

@MainActor
final class SnippetMonitor {
    static let shared = SnippetMonitor()
    private var monitor: Any?
    private var buffer = ""
    private weak var store: ClipboardStore?

    func start(store: ClipboardStore) {
        self.store = store
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in self?.consume(event) }
        }
    }

    func stop() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil; buffer = "" }

    private func consume(_ event: NSEvent) {
        guard let store, store.settings.snippetsEnabled else { return }
        if event.keyCode == 51 { buffer = String(buffer.dropLast()); return }
        guard let characters = event.characters, !characters.isEmpty, event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty else { buffer = ""; return }
        buffer = String((buffer + characters).suffix(80))
        guard let item = store.items.first(where: { item in
            guard !item.isSensitive, let snippet = item.snippet, !snippet.isEmpty else { return false }
            return buffer.hasSuffix(snippet)
        }) else { return }
        let target = NSWorkspace.shared.frontmostApplication
        guard target?.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        for _ in 0..<(item.snippet?.count ?? 0) { postBackspace() }
        store.paste(text: store.resolveTemplate(item.text), into: target)
        buffer = ""
    }

    private func postBackspace() {
        let source = CGEventSource(stateID: .hidSystemState)
        CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: true)?.post(tap: .cghidEventTap)
        CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: false)?.post(tap: .cghidEventTap)
    }
}
