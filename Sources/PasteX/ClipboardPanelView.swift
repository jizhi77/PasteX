import SwiftUI

struct ClipboardPanelView: View {
    @Bindable var store: ClipboardStore
    let onPaste: (ClipboardItem) -> Void
    let onPasteText: (ClipboardItem, String) -> Void
    let onSettings: () -> Void
    let onClose: () -> Void

    @State private var query = ""
    @State private var filter: HistoryFilter = .all
    @State private var selectedID: ClipboardItem.ID?
    @State private var selectedIDs = Set<ClipboardItem.ID>()
    @State private var editorItem: ClipboardItem?
    @State private var editorText = ""
    @State private var saveEditedCopy = false
    @State private var templateValues = [String: String]()
    @State private var aliasItem: ClipboardItem?
    @State private var aliasText = ""
    @State private var passwordManagerItem: ClipboardItem?
    @State private var passwordManagerURL = ""
    @State private var revealSensitiveIDs = Set<ClipboardItem.ID>()
    @State private var showingDeleteAllConfirmation = false
    @FocusState private var searchFocused: Bool

    private var filteredItems: [ClipboardItem] {
        store.items.filter { item in
            let isInFilter: Bool = switch filter {
            case .all: true
            case .favorites: item.isFavorite
            case .kind(let kind): item.kind == kind
            case .group(let name): item.group == name
            }
            guard isInFilter else { return false }
            guard !query.isEmpty else { return true }
            return item.text.localizedCaseInsensitiveContains(query) || (item.alias?.localizedCaseInsensitiveContains(query) ?? false) || (item.group?.localizedCaseInsensitiveContains(query) ?? false)
        }
        .sorted { query.isEmpty ? ($0.lastUsedAt ?? $0.createdAt) > ($1.lastUsedAt ?? $1.createdAt) : searchScore($0) > searchScore($1) }
    }

    private var selectedItem: ClipboardItem? {
        filteredItems.first { $0.id == selectedID }
    }

    var body: some View {
        applyingKeyboardShortcuts(to: panelLayout)
        .frame(width: 700, height: 500)
        .background(Design.Color.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Design.Color.separator, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onAppear { focusSearchAndSelectFirst() }
            .onReceive(NotificationCenter.default.publisher(for: .pasteXFocusSearch)) { _ in focusSearchAndSelectFirst() }
            .onChange(of: query) { _, _ in selectFirstIfNeeded() }
            .onChange(of: filter) { _, _ in selectFirstIfNeeded() }
            .sheet(item: $editorItem) { item in editorSheet(item) }
            .alert("Rename clipboard item", isPresented: Binding(get: { aliasItem != nil }, set: { if !$0 { aliasItem = nil } })) {
                TextField("Alias", text: $aliasText)
                Button("Cancel", role: .cancel) { aliasItem = nil }
                Button("Save") { if let aliasItem { store.setAlias(aliasText, for: aliasItem) }; aliasItem = nil }
            }
            .alert("Password manager link", isPresented: Binding(get: { passwordManagerItem != nil }, set: { if !$0 { passwordManagerItem = nil } })) {
                TextField("URL (for example, onepassword://)", text: $passwordManagerURL)
                Button("Cancel", role: .cancel) { passwordManagerItem = nil }
                Button("Save") { if let passwordManagerItem { store.setPasswordManagerURL(passwordManagerURL, for: passwordManagerItem) }; passwordManagerItem = nil }
            } message: { Text("Link a pinned item to your password manager instead of storing credentials in PasteX.") }
            .confirmationDialog("Delete all clipboard history?", isPresented: $showingDeleteAllConfirmation, titleVisibility: .visible) {
                Button("Delete Everything", role: .destructive) { store.deleteAll() }
            } message: { Text("This removes pinned and regular history from this Mac. This cannot be undone.") }
    }

    private var panelLayout: some View {
        HStack(spacing: 0) {
            sidebar
            Divider().overlay(Design.Color.separator)
            VStack(spacing: 0) {
                toolbar
                Divider().overlay(Design.Color.separator)
                content
            }
        }
    }

    @ViewBuilder
    private func applyingKeyboardShortcuts<V: View>(to content: V) -> some View {
        let returnHandler = content.onKeyPress(.return) {
            if let item = selectedItem { onPaste(item); return .handled }
            return .ignored
        }
        let navigationHandler = returnHandler
            .onKeyPress(.escape) { onClose(); return .handled }
            .onKeyPress(.upArrow) { moveSelection(by: -1); return .handled }
            .onKeyPress(.downArrow) { moveSelection(by: 1); return .handled }
        let deletionHandler = navigationHandler.onKeyPress(.delete) {
            if !selectedIDs.isEmpty { store.delete(selectedIDs); selectedIDs.removeAll(); selectFirstIfNeeded(); return .handled }
            if let item = selectedItem { store.delete(item); selectFirstIfNeeded(); return .handled }
            return .ignored
        }
        deletionHandler.onKeyPress(keys: Set((1...9).map { KeyEquivalent(Character(String($0))) })) { press in
            guard press.modifiers.contains(.command), let value = Int(String(press.key.character)), (1...9).contains(value) else { return .ignored }
            return quickPaste(at: value - 1)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: Design.Space.xs) {
            HStack(spacing: Design.Space.xs) {
                Image(systemName: "clipboard")
                    .font(.system(size: 15, weight: .semibold))
                Text("Clipboard History")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                if store.settings.isPaused {
                    Circle().fill(Design.Color.pause).frame(width: 7, height: 7)
                }
            }
            .padding(.bottom, Design.Space.sm)

            SidebarButton(title: "All history", symbol: "clock", selected: filter == .all) { filter = .all }
            SidebarButton(title: "Favorites", symbol: "star", selected: filter == .favorites) { filter = .favorites }
            Text("TYPES").font(.system(size: 10, weight: .semibold)).foregroundStyle(Design.Color.muted).padding(.top, Design.Space.sm).padding(.horizontal, Design.Space.xs)
            ForEach(ClipboardKind.allCases) { kind in SidebarButton(title: kind.title, symbol: kind.symbol, selected: filter == .kind(kind)) { filter = .kind(kind) } }

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
            Menu {
                if store.settings.isPaused { Button("Resume recording") { store.resumeRecording() } }
                else { ForEach(PauseDuration.allCases) { duration in Button(duration.title) { store.pause(for: duration) } } }
            } label: {
                Label(store.settings.isPaused ? "Recording paused" : "Recording active", systemImage: store.settings.isPaused ? "pause.fill" : "record.circle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(store.settings.isPaused ? Design.Color.pause : Design.Color.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 5)
            }
            .menuStyle(.borderlessButton)
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
            TextField("Search history", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($searchFocused)
            KeyHint(value: "⌘K")
            Spacer()
            if store.settings.isPaused {
                Text("PAUSED")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Design.Color.pause)
            }
            Menu {
                Button("Clear last 5 minutes", role: .destructive) { store.clearRecent(minutes: 5) }
                Button("Clear last 15 minutes", role: .destructive) { store.clearRecent(minutes: 15) }
                Button("Clear last 30 minutes", role: .destructive) { store.clearRecent(minutes: 30) }
                Button("Clear non-pinned history", role: .destructive) { store.clearHistory() }
                Button("Delete everything", role: .destructive) { showingDeleteAllConfirmation = true }
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
                                ClipboardRow(item: item, isSelected: selectedID == item.id, isBatchSelected: selectedIDs.contains(item.id), isRevealed: revealSensitiveIDs.contains(item.id), groups: store.settings.groups, onSelect: { selectedID = item.id }, onToggleSelection: { toggleBatchSelection(item) }, onPaste: { paste(item) }, onFavorite: { store.toggleFavorite(item) }, onGroup: { store.setGroup($0, for: item) }, onEdit: { beginEditing(item) }, onRename: { aliasItem = item; aliasText = item.alias ?? "" }, onPasswordManager: { passwordManagerItem = item; passwordManagerURL = item.passwordManagerURL ?? "" }, onOpenPasswordManager: { store.openPasswordManager(for: item) }, onReveal: { reveal(item) }, onDelete: { store.delete(item) })
                                    .id(item.id)
                            }
                            SectionLabel("RECENT")
                        }
                        ForEach(filteredItems.filter { !(filter == .all && query.isEmpty && $0.isFavorite) }) { item in
                            ClipboardRow(item: item, isSelected: selectedID == item.id, isBatchSelected: selectedIDs.contains(item.id), isRevealed: revealSensitiveIDs.contains(item.id), groups: store.settings.groups, onSelect: { selectedID = item.id }, onToggleSelection: { toggleBatchSelection(item) }, onPaste: { paste(item) }, onFavorite: { store.toggleFavorite(item) }, onGroup: { store.setGroup($0, for: item) }, onEdit: { beginEditing(item) }, onRename: { aliasItem = item; aliasText = item.alias ?? "" }, onPasswordManager: { passwordManagerItem = item; passwordManagerURL = item.passwordManagerURL ?? "" }, onOpenPasswordManager: { store.openPasswordManager(for: item) }, onReveal: { reveal(item) }, onDelete: { store.delete(item) })
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

    private func quickPaste(at index: Int) -> KeyPress.Result { guard filteredItems.indices.contains(index) else { return .ignored }; paste(filteredItems[index]); return .handled }
    private func toggleBatchSelection(_ item: ClipboardItem) { if selectedIDs.contains(item.id) { selectedIDs.remove(item.id) } else { selectedIDs.insert(item.id) } }
    private func beginEditing(_ item: ClipboardItem) { editorItem = item; editorText = item.text; saveEditedCopy = false; templateValues = Dictionary(uniqueKeysWithValues: store.templateFields(in: item.text).map { ($0, "") }) }
    private func paste(_ item: ClipboardItem) { if item.isSensitive && !revealSensitiveIDs.contains(item.id) { reveal(item, thenPaste: true) } else if item.isTemplate { beginEditing(item) } else { onPaste(item) } }
    private func reveal(_ item: ClipboardItem, thenPaste: Bool = false) { store.authenticateForSensitiveAccess { success in if success { revealSensitiveIDs.insert(item.id); DispatchQueue.main.asyncAfter(deadline: .now() + 60) { revealSensitiveIDs.remove(item.id) }; if thenPaste { onPaste(item) } } } }
    private func searchScore(_ item: ClipboardItem) -> Int { let needle = query.lowercased(); let text = "\(item.alias ?? "") \(item.text)".lowercased(); return (text.hasPrefix(needle) ? 4 : 0) + (item.alias?.lowercased().contains(needle) == true ? 2 : 0) + (text.contains(needle) ? 1 : 0) }
    private func editorSheet(_ item: ClipboardItem) -> some View { VStack(alignment: .leading, spacing: 14) { Text(item.isTemplate ? "Fill in and preview template" : "Edit before pasting").font(.headline); TextEditor(text: $editorText).font(.body).frame(minHeight: 150); if !templateValues.isEmpty { ForEach(templateValues.keys.sorted(), id: \.self) { field in TextField(field, text: Binding(get: { templateValues[field] ?? "" }, set: { templateValues[field] = $0 })) } }; if item.isTemplate { Text("Built-ins: {{date}}, {{time}}, {{clipboard}}. Custom fields are requested above.").font(.caption).foregroundStyle(Design.Color.muted) }; Toggle("Save as a new history item", isOn: $saveEditedCopy); HStack { Spacer(); Button("Cancel") { editorItem = nil }; Button("Paste") { let resolved = store.resolveTemplate(editorText, fields: templateValues); if saveEditedCopy { store.capture(text: resolved, sourceApp: "PasteX") }; onPasteText(item, resolved); editorItem = nil }.keyboardShortcut(.defaultAction) } }.padding(20).frame(width: 480) }
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

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: Design.Space.sm) {
                Image(systemName: item.isFavorite ? "star.fill" : item.kind.symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(item.isFavorite ? .yellow : Design.Color.muted)
                    .frame(width: 18, height: 20)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.isSensitive && !isRevealed ? "••••••••••••" : item.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    HStack(spacing: 7) {
                        Text(item.isSensitive && !isRevealed ? "Sensitive content — unlock to view" : item.preview)
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
                    HStack(spacing: 6) { if let source = item.sourceApp { Text(source) }; if item.isSensitive { Label("Protected", systemImage: "lock.fill") }; if item.isTemplate { Text("TEMPLATE") } }
                        .font(.system(size: 9, weight: .medium)).foregroundStyle(Design.Color.muted).lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(item.createdAt, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(Design.Color.muted)
                if isBatchSelected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor) }
                if isSelected { KeyHint(value: "↵") }
            }
            .padding(.horizontal, Design.Space.sm)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
            .background(isSelected ? Design.Color.selected : .clear, in: RoundedRectangle(cornerRadius: Design.Radius.small))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(item.isSensitive && !isRevealed ? "Unlock and paste" : "Paste as plain text", action: isRevealed || !item.isSensitive ? onPaste : onReveal)
            if item.isSensitive && !isRevealed { Button("Reveal with Touch ID / password", action: onReveal) }
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
        .onTapGesture(count: 2, perform: onPaste)
    }
}
