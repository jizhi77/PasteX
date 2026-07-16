import SwiftUI

struct ClipboardPanelView: View {
    @Bindable var store: ClipboardStore
    let onPaste: (ClipboardItem) -> Void
    let onSettings: () -> Void
    let onClose: () -> Void

    @State private var query = ""
    @State private var filter: HistoryFilter = .all
    @State private var selectedID: ClipboardItem.ID?
    @FocusState private var searchFocused: Bool

    private var filteredItems: [ClipboardItem] {
        store.items.filter { item in
            let isInFilter: Bool = switch filter {
            case .all: true
            case .favorites: item.isFavorite
            case .group(let name): item.group == name
            }
            guard isInFilter else { return false }
            guard !query.isEmpty else { return true }
            return item.text.localizedCaseInsensitiveContains(query) || (item.group?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private var selectedItem: ClipboardItem? {
        filteredItems.first { $0.id == selectedID }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider().overlay(Design.Color.separator)
            VStack(spacing: 0) {
                toolbar
                Divider().overlay(Design.Color.separator)
                content
            }
        }
        .frame(minWidth: 700, minHeight: 480)
        .background(Design.Color.panel)
        .onAppear { focusSearchAndSelectFirst() }
        .onReceive(NotificationCenter.default.publisher(for: .pasteXFocusSearch)) { _ in focusSearchAndSelectFirst() }
        .onChange(of: query) { _, _ in selectFirstIfNeeded() }
        .onChange(of: filter) { _, _ in selectFirstIfNeeded() }
        .onKeyPress(.return) {
            if let item = selectedItem { onPaste(item); return .handled }
            return .ignored
        }
        .onKeyPress(.escape) { onClose(); return .handled }
        .onKeyPress(.upArrow) { moveSelection(by: -1); return .handled }
        .onKeyPress(.downArrow) { moveSelection(by: 1); return .handled }
        .onKeyPress(.delete) {
            if let item = selectedItem { store.delete(item); selectFirstIfNeeded(); return .handled }
            return .ignored
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: Design.Space.xs) {
            HStack(spacing: Design.Space.xs) {
                Image(systemName: "clipboard")
                    .font(.system(size: 15, weight: .semibold))
                Text("PasteX")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                if store.settings.isRecordingPaused {
                    Circle().fill(Design.Color.pause).frame(width: 7, height: 7)
                }
            }
            .padding(.bottom, Design.Space.sm)

            SidebarButton(title: "All history", symbol: "clock", selected: filter == .all) { filter = .all }
            SidebarButton(title: "Favorites", symbol: "star", selected: filter == .favorites) { filter = .favorites }

            Text("GROUPS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Design.Color.muted)
                .padding(.top, Design.Space.md)
                .padding(.horizontal, Design.Space.xs)
            ForEach(store.settings.groups, id: \.self) { group in
                SidebarButton(title: group, symbol: "folder", selected: filter == .group(group)) { filter = .group(group) }
            }
            Spacer()
            Divider().overlay(Design.Color.separator)
            Button {
                store.settings.isRecordingPaused.toggle()
            } label: {
                Label(store.settings.isRecordingPaused ? "Recording paused" : "Recording active", systemImage: store.settings.isRecordingPaused ? "pause.fill" : "record.circle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(store.settings.isRecordingPaused ? Design.Color.pause : Design.Color.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.plain)
            Button(action: onSettings) {
                Label("Settings", systemImage: "gearshape")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Design.Color.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.plain)
        }
        .padding(Design.Space.md)
        .frame(width: 170)
    }

    private var toolbar: some View {
        HStack(spacing: Design.Space.sm) {
            Image(systemName: "magnifyingglass").foregroundStyle(Design.Color.muted)
            TextField("Search clipboard history", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($searchFocused)
            KeyHint(value: "⌘K")
            Spacer()
            if store.settings.isRecordingPaused {
                Text("PAUSED")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Design.Color.pause)
            }
            Menu {
                Button("Clear non-favorites", role: .destructive) { store.clearHistory() }
                Button("Delete everything", role: .destructive) { store.deleteAll() }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 15))
                    .foregroundStyle(Design.Color.muted)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, Design.Space.md)
        .frame(height: 52)
    }

    @ViewBuilder
    private var content: some View {
        if filteredItems.isEmpty {
            VStack(spacing: Design.Space.sm) {
                Image(systemName: query.isEmpty ? "clipboard" : "magnifyingglass")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(Design.Color.muted)
                Text(query.isEmpty ? "Your clipboard is ready" : "No matches")
                    .font(.system(size: 14, weight: .medium))
                Text(query.isEmpty ? "Copy text anywhere to build your history." : "Try another phrase or filter.")
                    .font(.system(size: 12))
                    .foregroundStyle(Design.Color.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        if filter == .all && query.isEmpty, !store.items.filter(\.isFavorite).isEmpty {
                            SectionLabel("FAVORITES")
                            ForEach(store.items.filter(\.isFavorite)) { item in
                                ClipboardRow(item: item, isSelected: selectedID == item.id, groups: store.settings.groups, onSelect: { selectedID = item.id }, onPaste: { onPaste(item) }, onFavorite: { store.toggleFavorite(item) }, onGroup: { store.setGroup($0, for: item) }, onDelete: { store.delete(item) })
                                    .id(item.id)
                            }
                            SectionLabel("RECENT")
                        }
                        ForEach(filteredItems.filter { !(filter == .all && query.isEmpty && $0.isFavorite) }) { item in
                            ClipboardRow(item: item, isSelected: selectedID == item.id, groups: store.settings.groups, onSelect: { selectedID = item.id }, onPaste: { onPaste(item) }, onFavorite: { store.toggleFavorite(item) }, onGroup: { store.setGroup($0, for: item) }, onDelete: { store.delete(item) })
                                .id(item.id)
                        }
                    }
                    .padding(Design.Space.sm)
                }
                .onChange(of: selectedID) { _, id in
                    if let id { withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(id, anchor: .center) } }
                }
            }
        }
    }

    private func focusSearchAndSelectFirst() {
        searchFocused = true
        selectFirstIfNeeded()
    }

    private func selectFirstIfNeeded() {
        if !filteredItems.contains(where: { $0.id == selectedID }) { selectedID = filteredItems.first?.id }
    }

    private func moveSelection(by offset: Int) {
        guard !filteredItems.isEmpty else { return }
        let currentIndex = filteredItems.firstIndex { $0.id == selectedID } ?? 0
        selectedID = filteredItems[max(0, min(filteredItems.count - 1, currentIndex + offset))].id
    }
}

private struct SidebarButton: View {
    let title: String
    let symbol: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? .primary : Design.Color.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Design.Space.xs)
                .padding(.vertical, 6)
                .background(selected ? Design.Color.selected : .clear, in: RoundedRectangle(cornerRadius: Design.Radius.small))
        }
        .buttonStyle(.plain)
    }
}

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Design.Color.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Design.Space.xs)
            .padding(.bottom, 2)
    }
}

private struct ClipboardRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let groups: [String]
    let onSelect: () -> Void
    let onPaste: () -> Void
    let onFavorite: () -> Void
    let onGroup: (String?) -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: Design.Space.sm) {
                Image(systemName: item.isFavorite ? "star.fill" : "doc.text")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(item.isFavorite ? .yellow : Design.Color.muted)
                    .frame(width: 18, height: 20)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    HStack(spacing: 7) {
                        Text(item.preview)
                            .lineLimit(1)
                        if let group = item.group {
                            Text(group.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Design.Color.elevated, in: Capsule())
                        }
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(Design.Color.muted)
                }
                Spacer(minLength: 8)
                Text(item.createdAt, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(Design.Color.muted)
                if isSelected { KeyHint(value: "↵") }
            }
            .padding(.horizontal, Design.Space.sm)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
            .background(isSelected ? Design.Color.selected : .clear, in: RoundedRectangle(cornerRadius: Design.Radius.small))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Paste as plain text", action: onPaste)
            Button(item.isFavorite ? "Remove from favorites" : "Add to favorites", action: onFavorite)
            Menu("Move to group") {
                Button("No group") { onGroup(nil) }
                ForEach(groups, id: \.self) { group in Button(group) { onGroup(group) } }
            }
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
        .onTapGesture(count: 2, perform: onPaste)
    }
}
