import Foundation

enum ClipboardKind: String, Codable, CaseIterable, Identifiable {
    case text, link, code, color

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .text: "doc.text"
        case .link: "link"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .color: "paintpalette"
        }
    }

    static func detect(_ text: String) -> ClipboardKind {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.range(of: "^#[0-9A-Fa-f]{3,8}$", options: .regularExpression) != nil { return .color }
        if let url = URL(string: trimmed), let scheme = url.scheme, ["http", "https", "mailto"].contains(scheme.lowercased()) { return .link }
        if text.contains("\n") || text.range(of: "\\b(func|let|var|class|struct|import|const|function)\\b", options: [.regularExpression, .caseInsensitive]) != nil { return .code }
        return .text
    }
}

enum RetentionPeriod: Int, Codable, CaseIterable, Identifiable {
    case oneDay = 1, sevenDays = 7, thirtyDays = 30, forever = 0
    var id: Int { rawValue }
    var title: String { switch self { case .oneDay: "1 day"; case .sevenDays: "7 days"; case .thirtyDays: "30 days"; case .forever: "Forever" } }
}

enum PauseDuration: Int, CaseIterable, Identifiable {
    case fiveMinutes = 300, fifteenMinutes = 900, indefinitely = 0
    var id: Int { rawValue }
    var title: String { switch self { case .fiveMinutes: "Pause 5 minutes"; case .fifteenMinutes: "Pause 15 minutes"; case .indefinitely: "Pause until resumed" } }
}

enum SensitiveExpiry: Int, Codable, CaseIterable, Identifiable {
    case thirtySeconds = 30, fiveMinutes = 300, fifteenMinutes = 900
    var id: Int { rawValue }
    var title: String { switch self { case .thirtySeconds: "30 seconds"; case .fiveMinutes: "5 minutes"; case .fifteenMinutes: "15 minutes" } }
}

enum HotKeyChoice: String, Codable, CaseIterable, Identifiable {
    case optionSpace, commandShiftV
    var id: String { rawValue }
    var title: String { switch self { case .optionSpace: "Option-Space"; case .commandShiftV: "Command-Shift-V" } }
}

struct ClipboardItem: Identifiable, Codable, Equatable {
    var id: UUID
    var text: String
    var createdAt: Date
    var lastUsedAt: Date?
    var sourceApp: String?
    var sourceBundleID: String?
    var kind: ClipboardKind
    var isFavorite: Bool
    var group: String?
    var alias: String?
    var isSensitive: Bool
    var expiresAt: Date?
    var snippet: String?
    var passwordManagerURL: String?

    init(id: UUID = UUID(), text: String, createdAt: Date = .now, sourceApp: String? = nil, sourceBundleID: String? = nil, isFavorite: Bool = false, group: String? = nil, alias: String? = nil, isSensitive: Bool = false, expiresAt: Date? = nil, snippet: String? = nil, passwordManagerURL: String? = nil) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.lastUsedAt = nil
        self.sourceApp = sourceApp
        self.sourceBundleID = sourceBundleID
        self.kind = ClipboardKind.detect(text)
        self.isFavorite = isFavorite
        self.group = group
        self.alias = alias
        self.isSensitive = isSensitive
        self.expiresAt = expiresAt
        self.snippet = snippet
        self.passwordManagerURL = passwordManagerURL
    }

    var title: String { alias?.isEmpty == false ? alias! : (text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text) }
    var preview: String { text.replacingOccurrences(of: "\\n", with: " ").replacingOccurrences(of: "\\t", with: " ") }
    var isTemplate: Bool { text.contains("{{") && text.contains("}}") }
}

struct AppSettings: Codable, Equatable {
    var isRecordingPaused = false
    var pausedUntil: Date?
    var retentionPeriod: RetentionPeriod = .thirtyDays
    var maximumTextLength = 10_000
    var maximumItems = 500
    var groups = ["Work", "Personal", "Snippets"]
    var ignoredAppBundleIDs = ["com.apple.Passwords", "com.apple.KeychainAccess", "com.agilebits.onepassword7", "com.1password.1password", "com.bitwarden.desktop"]
    var saveSensitiveItems = false
    var sensitiveExpiry: SensitiveExpiry = .fiveMinutes
    var clearPasteboardAfterSensitivePaste = true
    var strictPrivacyMode = false
    var defaultPastePlainText = true
    var hotKey: HotKeyChoice = .optionSpace
    var quickMenuNearCursor = true
    var snippetsEnabled = true
    var preferredPasswordManagers = ["Apple Passwords", "1Password", "Bitwarden"]

    var isPaused: Bool {
        guard isRecordingPaused else { return false }
        if let pausedUntil { return pausedUntil > .now }
        return true
    }
}

struct PersistedState: Codable {
    var items: [ClipboardItem]
    var settings: AppSettings
}

enum HistoryFilter: Hashable {
    case all, favorites, kind(ClipboardKind), group(String)
    var title: String {
        switch self {
        case .all: "All history"
        case .favorites: "Favorites"
        case .kind(let kind): kind.title
        case .group(let name): name
        }
    }
}
