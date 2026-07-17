import SwiftUI

enum PasteXStyle {
    static let cardRadius: CGFloat = 12
    static let inputRadius: CGFloat = 10
    static let thumbnailRadius: CGFloat = 8
    static let cardSpacing: CGFloat = 8
    static let motion = Animation.spring(response: 0.34, dampingFraction: 0.8, blendDuration: 0.08)
    static let gentleMotion = Animation.easeOut(duration: 0.18)
}

extension View {
    func historyCardSurface(isHighlighted: Bool, isHovered: Bool) -> some View {
        background(.thickMaterial, in: RoundedRectangle(cornerRadius: PasteXStyle.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PasteXStyle.cardRadius, style: .continuous)
                    .fill(Color(nsColor: .selectedContentBackgroundColor).opacity(isHighlighted ? 0.22 : (isHovered ? 0.10 : 0)))
            }
            .overlay {
                RoundedRectangle(cornerRadius: PasteXStyle.cardRadius, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(isHovered ? 0.42 : 0.22), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(isHovered ? 0.08 : 0.055), radius: 6, x: 0, y: isHovered ? 3 : 2)
    }
}

extension Date {
    var pasteXRelativeDescription: String {
        let calendar = Calendar.current
        let seconds = max(0, Int(Date.now.timeIntervalSince(self)))
        if seconds < 45 { return "Just now" }
        if seconds < 3_600 { return "\(seconds / 60)m ago" }
        if calendar.isDateInToday(self) { return DateFormatter.localizedString(from: self, dateStyle: .none, timeStyle: .short) }
        if calendar.isDateInYesterday(self) { return "Yesterday" }
        return DateFormatter.localizedString(from: self, dateStyle: .short, timeStyle: .none)
    }
}

func highlightedHistoryText(_ value: String, query: String) -> Text {
    guard !query.isEmpty, let match = value.range(of: query, options: .caseInsensitive) else { return Text(value) }
    let prefix = String(value[..<match.lowerBound])
    let hit = String(value[match])
    let suffix = String(value[match.upperBound...])
    return Text(prefix) + Text(hit).foregroundColor(.accentColor) + Text(suffix)
}
