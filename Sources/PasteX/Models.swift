import Foundation

struct ClipboardItem: Identifiable, Codable, Equatable {
    var id: UUID
    var text: String
    var createdAt: Date
    var isFavorite: Bool
    var group: String?

    init(id: UUID = UUID(), text: String, createdAt: Date = .now, isFavorite: Bool = false, group: String? = nil) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.isFavorite = isFavorite
        self.group = group
    }

    var title: String {
        text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
    }

    var preview: String {
        text.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\t", with: " ")
    }
}

struct AppSettings: Codable, Equatable {
    var isRecordingPaused = false
    var retentionDays = 30
    var maximumTextLength = 10_000
    var maximumItems = 500
    var groups = ["Work", "Personal", "Snippets"]
}

struct PersistedState: Codable {
    var items: [ClipboardItem]
    var settings: AppSettings
}

enum HistoryFilter: Hashable {
    case all
    case favorites
    case group(String)

    var title: String {
        switch self {
        case .all: "All history"
        case .favorites: "Favorites"
        case .group(let name): name
        }
    }
}
