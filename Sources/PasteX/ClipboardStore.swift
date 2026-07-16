import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class ClipboardStore {
    private(set) var items: [ClipboardItem] = []
    var settings = AppSettings() { didSet { pruneAndSave() } }
    var lastCapturedText = ""

    private let fileURL: URL
    private var pasteboardChangeCount = NSPasteboard.general.changeCount
    private var monitor: Timer?

    init() {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PasteX", isDirectory: true)
        try? FileManager.default.createDirectory(at: applicationSupport, withIntermediateDirectories: true)
        fileURL = applicationSupport.appendingPathComponent("history.json")
        load()
        pruneAndSave()
    }

    func startMonitoring() {
        guard monitor == nil else { return }
        monitor = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.capturePasteboardIfNeeded() }
        }
    }

    func stopMonitoring() {
        monitor?.invalidate()
        monitor = nil
    }

    func capturePasteboardIfNeeded() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != pasteboardChangeCount else { return }
        pasteboardChangeCount = pasteboard.changeCount
        guard !settings.isRecordingPaused,
              let text = pasteboard.string(forType: .string) else { return }
        capture(text: text)
    }

    func capture(text: String) {
        guard !text.trimmingCharacters(in: .newlines).isEmpty,
              text.utf8.count <= settings.maximumTextLength else { return }
        lastCapturedText = text

        if let existingIndex = items.firstIndex(where: { $0.text == text }) {
            var existing = items.remove(at: existingIndex)
            existing.createdAt = .now
            items.insert(existing, at: 0)
        } else {
            items.insert(ClipboardItem(text: text), at: 0)
        }
        pruneAndSave()
    }

    func toggleFavorite(_ item: ClipboardItem) {
        update(item) { $0.isFavorite.toggle() }
    }

    func setGroup(_ group: String?, for item: ClipboardItem) {
        update(item) { $0.group = group }
    }

    func delete(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func clearHistory() {
        items.removeAll { !$0.isFavorite }
        save()
    }

    func deleteAll() {
        items.removeAll()
        save()
    }

    func addGroup(named rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !settings.groups.contains(name) else { return }
        settings.groups.append(name)
    }

    func paste(_ item: ClipboardItem, into target: NSRunningApplication?) {
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(item.text, forType: .string)
        pasteboardChangeCount = board.changeCount
        activateAndPaste(into: target)
    }

    func copy(_ item: ClipboardItem) {
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(item.text, forType: .string)
        pasteboardChangeCount = board.changeCount
    }

    private func update(_ item: ClipboardItem, transform: (inout ClipboardItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        transform(&items[index])
        save()
    }

    private func activateAndPaste(into target: NSRunningApplication?) {
        let accessibilityPrompt = ["AXTrustedCheckOptionPrompt" as CFString: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(accessibilityPrompt) else { return }
        target?.activate(options: [])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            let source = CGEventSource(stateID: .hidSystemState)
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true) // V
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
            keyDown?.flags = .maskCommand
            keyUp?.flags = .maskCommand
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }
    }

    private func pruneAndSave() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -settings.retentionDays, to: .now) ?? .distantPast
        items.removeAll { !$0.isFavorite && $0.createdAt < cutoff }
        let favorites = items.filter(\.isFavorite)
        let history = items.filter { !$0.isFavorite }.prefix(settings.maximumItems)
        items = favorites + Array(history)
        items.sort { $0.createdAt > $1.createdAt }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data) else { return }
        items = state.items
        settings = state.settings
    }

    private func save() {
        let state = PersistedState(items: items, settings: settings)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
