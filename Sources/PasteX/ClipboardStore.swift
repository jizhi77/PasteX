import AppKit
import CryptoKit
import Foundation
import Observation
import Security

@MainActor
@Observable
final class ClipboardStore {
    private(set) var items: [ClipboardItem] = []
    var settings = AppSettings() { didSet { pruneAndSave() } }
    var lastCapturedText = ""
    var lastError: String?

    private let fileURL: URL
    private let legacyFileURL: URL
    private var pasteboardChangeCount = NSPasteboard.general.changeCount
    private var monitor: Timer?

    init() {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PasteX", isDirectory: true)
        try? FileManager.default.createDirectory(at: applicationSupport, withIntermediateDirectories: true)
        fileURL = applicationSupport.appendingPathComponent("history.pastex")
        legacyFileURL = applicationSupport.appendingPathComponent("history.json")
        load()
        pruneAndSave()
    }

    func startMonitoring() {
        guard monitor == nil else { return }
        monitor = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.capturePasteboardIfNeeded() }
        }
        SnippetMonitor.shared.start(store: self)
    }

    func stopMonitoring() {
        monitor?.invalidate()
        monitor = nil
        SnippetMonitor.shared.stop()
    }

    func capturePasteboardIfNeeded() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != pasteboardChangeCount else { return }
        pasteboardChangeCount = pasteboard.changeCount
        guard !settings.isPaused, let text = pasteboard.string(forType: .string) else { return }
        let app = NSWorkspace.shared.frontmostApplication
        capture(text: text, sourceApp: app?.localizedName, sourceBundleID: app?.bundleIdentifier)
    }

    func capture(text: String, sourceApp: String? = nil, sourceBundleID: String? = nil) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              text.utf8.count <= settings.maximumTextLength,
              !settings.ignoredAppBundleIDs.contains(sourceBundleID ?? "") else { return }
        let sensitive = isSensitive(text)
        guard !sensitive || settings.saveSensitiveItems else { return }
        lastCapturedText = text
        let expiry = sensitive ? Date.now.addingTimeInterval(TimeInterval(settings.sensitiveExpiry.rawValue)) : nil

        if let existingIndex = items.firstIndex(where: { $0.text == text }) {
            var existing = items.remove(at: existingIndex)
            existing.createdAt = .now
            existing.sourceApp = sourceApp ?? existing.sourceApp
            existing.sourceBundleID = sourceBundleID ?? existing.sourceBundleID
            existing.isSensitive = sensitive
            existing.expiresAt = expiry
            items.insert(existing, at: 0)
        } else {
            items.insert(ClipboardItem(text: text, sourceApp: sourceApp, sourceBundleID: sourceBundleID, isSensitive: sensitive, expiresAt: expiry), at: 0)
        }
        pruneAndSave()
    }

    func toggleFavorite(_ item: ClipboardItem) { update(item) { $0.isFavorite.toggle() } }
    func setGroup(_ group: String?, for item: ClipboardItem) { update(item) { $0.group = group } }
    func setAlias(_ alias: String?, for item: ClipboardItem) { update(item) { $0.alias = alias?.trimmingCharacters(in: .whitespacesAndNewlines) } }
    func setSnippet(_ snippet: String?, for item: ClipboardItem) { update(item) { $0.snippet = snippet?.trimmingCharacters(in: .whitespacesAndNewlines) } }
    func setPasswordManagerURL(_ url: String?, for item: ClipboardItem) { update(item) { $0.passwordManagerURL = url } }

    func replaceGroup(_ oldName: String, with newName: String) {
        let clean = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean != oldName, !settings.groups.contains(clean) else { return }
        settings.groups = settings.groups.map { $0 == oldName ? clean : $0 }
        for index in items.indices where items[index].group == oldName { items[index].group = clean }
        save()
    }

    func deleteGroup(_ name: String) {
        settings.groups.removeAll { $0 == name }
        for index in items.indices where items[index].group == name { items[index].group = nil }
        save()
    }

    func delete(_ item: ClipboardItem) { items.removeAll { $0.id == item.id }; save() }
    func delete(_ selected: Set<ClipboardItem.ID>) { items.removeAll { selected.contains($0.id) }; save() }
    func clearHistory() { items.removeAll { !$0.isFavorite }; save() }
    func clearRecent(minutes: Int) { let cutoff = Date.now.addingTimeInterval(-TimeInterval(minutes * 60)); items.removeAll { !$0.isFavorite && $0.createdAt >= cutoff }; save() }
    func deleteAll() { items.removeAll(); save() }

    func addGroup(named rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !settings.groups.contains(name) else { return }
        settings.groups.append(name)
    }

    func pause(for duration: PauseDuration) {
        settings.isRecordingPaused = true
        settings.pausedUntil = duration == .indefinitely ? nil : Date.now.addingTimeInterval(TimeInterval(duration.rawValue))
    }

    func resumeRecording() { settings.isRecordingPaused = false; settings.pausedUntil = nil }
    func restoreDefaults() { settings = AppSettings() }

    func paste(_ item: ClipboardItem, into target: NSRunningApplication?, textOverride: String? = nil) {
        paste(text: textOverride ?? item.text, into: target, isSensitive: item.isSensitive)
        update(item) { $0.lastUsedAt = .now }
    }

    func paste(text: String, into target: NSRunningApplication?, isSensitive: Bool = false) {
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(text, forType: .string)
        pasteboardChangeCount = board.changeCount
        activateAndPaste(into: target)
        if isSensitive && settings.clearPasteboardAfterSensitivePaste {
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in self?.clearPasteboardIfUnchanged(text) }
        }
    }

    func copy(_ item: ClipboardItem) {
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(item.text, forType: .string)
        pasteboardChangeCount = board.changeCount
    }

    func resolveTemplate(_ text: String, fields: [String: String] = [:]) -> String {
        var result = text
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        result = result.replacingOccurrences(of: "{{date}}", with: formatter.string(from: .now))
        let time = DateFormatter.localizedString(from: .now, dateStyle: .none, timeStyle: .short)
        result = result.replacingOccurrences(of: "{{time}}", with: time)
        result = result.replacingOccurrences(of: "{{clipboard}}", with: NSPasteboard.general.string(forType: .string) ?? lastCapturedText)
        for (key, value) in fields { result = result.replacingOccurrences(of: "{{\(key)}}", with: value) }
        return result
    }

    func templateFields(in text: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: "\\\\{\\\\{\\\\s*([^}\\\\s]+)\\\\s*\\\\}\\\\}") else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return expression.matches(in: text, range: range).compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            let name = String(text[range])
            return ["date", "time", "clipboard"].contains(name) ? nil : name
        }
    }

    func authenticateForSensitiveAccess(completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        PrivacyAuthenticator.authenticate(completion: completion)
    }

    func openPasswordManager(for item: ClipboardItem) {
        guard let value = item.passwordManagerURL, let url = URL(string: value) else { return }
        NSWorkspace.shared.open(url)
    }

    private func update(_ item: ClipboardItem, transform: (inout ClipboardItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        transform(&items[index]); save()
    }

    private func activateAndPaste(into target: NSRunningApplication?) {
        let accessibilityPrompt = ["AXTrustedCheckOptionPrompt" as CFString: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(accessibilityPrompt) else { lastError = "Accessibility permission is required to paste into another app."; return }
        target?.activate(options: [])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { Self.postPasteShortcut() }
    }

    static func postPasteShortcut() {
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        down?.flags = .maskCommand; up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap); up?.post(tap: .cghidEventTap)
    }

    private func clearPasteboardIfUnchanged(_ value: String) {
        let board = NSPasteboard.general
        guard board.string(forType: .string) == value else { return }
        board.clearContents(); pasteboardChangeCount = board.changeCount
    }

    private func isSensitive(_ text: String) -> Bool {
        let patterns = ["(?i)password\\\\s*[:=]", "(?i)api[_-]?key\\\\s*[:=]", "(?i)secret\\\\s*[:=]", "-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----", "(?i)\\\\b(otp|verification code|验证码)\\\\b", "\\\\b[A-Za-z0-9_-]{20,}\\\\.[A-Za-z0-9_-]{10,}\\\\.[A-Za-z0-9_-]{10,}\\\\b"]
        return patterns.contains { text.range(of: $0, options: .regularExpression) != nil } || (text.count >= 6 && text.count <= 12 && text.allSatisfy(\.isNumber))
    }

    private func pruneAndSave() {
        if settings.isRecordingPaused, let until = settings.pausedUntil, until <= .now { settings.isRecordingPaused = false; settings.pausedUntil = nil; return }
        let cutoff: Date? = settings.retentionPeriod == .forever ? nil : Calendar.current.date(byAdding: .day, value: -settings.retentionPeriod.rawValue, to: .now)
        items.removeAll { item in
            if let expiresAt = item.expiresAt, expiresAt <= .now { return true }
            return !item.isFavorite && cutoff.map { item.createdAt < $0 } == true
        }
        let favorites = items.filter(\.isFavorite)
        let history = items.filter { !$0.isFavorite }.prefix(settings.maximumItems)
        items = favorites + Array(history)
        items.sort { ($0.isFavorite == $1.isFavorite) ? $0.createdAt > $1.createdAt : $0.isFavorite }
        save()
    }

    private func load() {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        if let encrypted = try? Data(contentsOf: fileURL), let data = try? LocalCipher.open(encrypted), let state = try? decoder.decode(PersistedState.self, from: data) { items = state.items; settings = state.settings; return }
        if let legacy = try? Data(contentsOf: legacyFileURL), let state = try? JSONDecoder().decode(PersistedState.self, from: legacy) {
            items = state.items; settings = state.settings; save(); try? FileManager.default.removeItem(at: legacyFileURL)
        }
    }

    private func save() {
        let state = PersistedState(items: items, settings: settings)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(state), let encrypted = try? LocalCipher.seal(data) else { lastError = "Could not securely save local history."; return }
        try? encrypted.write(to: fileURL, options: .atomic)
    }
}
