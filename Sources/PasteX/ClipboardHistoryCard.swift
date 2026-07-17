import SwiftUI

struct ClipboardHistoryCard: View {
    let item: ClipboardItem
    let query: String
    let isSelected: Bool
    let isBatchSelected: Bool
    let isRevealed: Bool
    let groups: [String]
    let onSelect: () -> Void
    let onToggleSelection: () -> Void
    let onPaste: () -> Void
    let onFavorite: () -> Void
    let onGroup: (String?) -> Void
    let onEdit: () -> Void
    let onRename: () -> Void
    let onPasswordManager: () -> Void
    let onOpenPasswordManager: () -> Void
    let onReveal: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var isExpanded = false
    @State private var didPaste = false

    private var isProtected: Bool { item.isSensitive && !isRevealed }
    private var isFilePath: Bool { item.text.hasPrefix("/") || item.text.hasPrefix("~/") || item.text.hasPrefix("file://") }
    private var visibleText: String { isProtected ? "Sensitive content" : item.preview }

    var body: some View {
        Button(action: selectAndPaste) {
            HStack(alignment: .top, spacing: 12) {
                leadingIcon
                VStack(alignment: .leading, spacing: 7) {
                    titleLine
                    contentPreview
                    metadataLine
                }
                Spacer(minLength: 12)
                trailingMetadata
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .contentShape(RoundedRectangle(cornerRadius: PasteXStyle.cardRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .historyCardSurface(isHighlighted: isSelected || didPaste, isHovered: isHovered)
        .offset(y: isHovered ? -1 : 0)
        .scaleEffect(isHovered ? 1.002 : 1)
        .animation(PasteXStyle.gentleMotion, value: isHovered)
        .onHover { isHovered = $0 }
        .onLongPressGesture(minimumDuration: 0.35) { withAnimation(PasteXStyle.gentleMotion) { isExpanded.toggle() } }
        .contextMenu { contextMenu }
    }

    private var leadingIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: PasteXStyle.thumbnailRadius, style: .continuous)
                .fill(.ultraThinMaterial)
            Image(systemName: isFilePath ? "doc" : (item.isFavorite ? "star.fill" : item.kind.symbol))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(item.isFavorite ? .yellow : .secondary)
        }
        .frame(width: 30, height: 30)
    }

    private var titleLine: some View {
        HStack(spacing: 7) {
            highlightedHistoryText(isProtected ? "••••••••••••" : item.title, query: query)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(isExpanded ? nil : 1)
            if item.isFavorite {
                Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(.yellow.opacity(0.85))
            }
            if item.lastUsedAt != nil {
                Text("REUSED").font(.system(size: 9, weight: .medium)).foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private var contentPreview: some View {
        if isProtected {
            Text("••••••••••••••••••••••••")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .blur(radius: 3.5)
        } else if item.kind == .code {
            highlightedHistoryText(visibleText, query: query)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(isExpanded ? nil : 2)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: PasteXStyle.thumbnailRadius, style: .continuous))
        } else if isFilePath {
            HStack(spacing: 6) {
                Image(systemName: "folder").foregroundStyle(.secondary)
                Text(visibleText).lineLimit(1).truncationMode(.middle)
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        } else {
            highlightedHistoryText(visibleText, query: query)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(isExpanded ? nil : 2)
        }
    }

    private var metadataLine: some View {
        HStack(spacing: 7) {
            if let source = item.sourceApp { Text(source) }
            if let group = item.group { Text(group) }
            if item.isSensitive { Label("Protected", systemImage: "lock.fill") }
            if item.isTemplate { Text("Template") }
        }
        .font(.system(size: 11))
        .foregroundStyle(.tertiary)
        .lineLimit(1)
    }

    private var trailingMetadata: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text(item.createdAt.pasteXRelativeDescription)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            if didPaste { Image(systemName: "checkmark").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary) }
            else if isBatchSelected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor) }
            else if isSelected { KeyHint(value: "↵") }
        }
    }

    @ViewBuilder
    private var contextMenu: some View {
        Button(isProtected ? "Unlock and paste" : "Paste as plain text") { isProtected ? onReveal() : pasteWithFeedback() }
        if isProtected { Button("Reveal with Touch ID / password", action: onReveal) }
        Button("Edit before pasting…", action: onEdit)
        Button("Rename…", action: onRename)
        if item.isFavorite { Button(item.passwordManagerURL == nil ? "Add password manager link…" : "Edit password manager link…", action: onPasswordManager) }
        if item.passwordManagerURL != nil { Button("Open password manager", action: onOpenPasswordManager) }
        Button("Select for batch delete", action: onToggleSelection)
        Button(item.isFavorite ? "Remove from favorites" : "Add to favorites", action: onFavorite)
        Menu("Move to group") {
            Button("No group") { onGroup(nil) }
            ForEach(groups, id: \.self) { group in Button(group) { onGroup(group) } }
        }
        Divider()
        Button("Delete", role: .destructive, action: onDelete)
    }

    private func pasteWithFeedback() {
        didPaste = true
        onPaste()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { didPaste = false }
    }

    private func selectAndPaste() {
        onSelect()
        pasteWithFeedback()
    }
}
