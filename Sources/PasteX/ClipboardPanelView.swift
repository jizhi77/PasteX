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
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 0.5))
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
        ZStack {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.11), .clear, Color.accentColor.opacity(0.035)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 0) {
                toolbar
                Divider().overlay(Color(nsColor: .separatorColor).opacity(0.35))
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

    private var toolbar: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(.ultraThinMaterial)
                Image(systemName: "clipboard")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text("History").font(.system(size: 13, weight: .medium))
                Text("\(filteredItems.count) · \(filter.title)").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            HistorySearchBar(query: $query, focus: $searchFocused, compact: true)
                .frame(maxWidth: .infinity)
            HStack(spacing: 9) {
                if store.settings.isPaused {
                    Circle().fill(Design.Color.pause).frame(width: 6, height: 6)
                }
                recordingMenu
                filterMenu
                cleanupMenu
                settingsButton
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var recordingMenu: some View {
        Menu {
            if store.settings.isPaused {
                Button("Resume recording") { store.resumeRecording() }
            } else {
                ForEach(PauseDuration.allCases) { duration in Button(duration.title) { store.pause(for: duration) } }
            }
        } label: {
            Image(systemName: store.settings.isPaused ? "pause.circle" : "record.circle")
                .font(.system(size: 15))
                .foregroundStyle(store.settings.isPaused ? Design.Color.pause : .secondary)
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel(store.settings.isPaused ? "Recording paused" : "Recording active")
    }

    private var settingsButton: some View {
        Button(action: onSettings) {
            Image(systemName: "gearshape")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open settings")
    }

    private var filterMenu: some View {
        Menu {
            Button("All history") { filter = .all }
            Button("Favorites") { filter = .favorites }
            Divider()
            Menu("Type") { ForEach(ClipboardKind.allCases) { kind in Button(kind.title) { filter = .kind(kind) } } }
            Menu("Group") { ForEach(store.settings.groups, id: \.self) { group in Button(group) { filter = .group(group) } } }
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(filter == .all ? Design.Color.muted : Color.accentColor)
        }
        .menuStyle(.borderlessButton)
    }

    private var cleanupMenu: some View {
        Menu {
            Button("Clear last 5 minutes", role: .destructive) { store.clearRecent(minutes: 5) }
            Button("Clear last 15 minutes", role: .destructive) { store.clearRecent(minutes: 15) }
            Button("Clear last 30 minutes", role: .destructive) { store.clearRecent(minutes: 30) }
            Button("Clear non-pinned history", role: .destructive) { store.clearHistory() }
            Button("Delete everything", role: .destructive) { showingDeleteAllConfirmation = true }
        } label: {
            Image(systemName: "ellipsis.circle").font(.system(size: 15)).foregroundStyle(Design.Color.muted)
        }
        .menuStyle(.borderlessButton)
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
                    LazyVStack(spacing: PasteXStyle.cardSpacing) {
                        if filter == .all && query.isEmpty, !store.items.filter(\.isFavorite).isEmpty {
                            SectionLabel("FAVORITES")
                            ForEach(store.items.filter(\.isFavorite)) { item in
                                ClipboardHistoryCard(item: item, query: query, isSelected: selectedID == item.id, isBatchSelected: selectedIDs.contains(item.id), isRevealed: revealSensitiveIDs.contains(item.id), groups: store.settings.groups, onSelect: { selectedID = item.id }, onToggleSelection: { toggleBatchSelection(item) }, onPaste: { paste(item) }, onFavorite: { store.toggleFavorite(item) }, onGroup: { store.setGroup($0, for: item) }, onEdit: { beginEditing(item) }, onRename: { aliasItem = item; aliasText = item.alias ?? "" }, onPasswordManager: { passwordManagerItem = item; passwordManagerURL = item.passwordManagerURL ?? "" }, onOpenPasswordManager: { store.openPasswordManager(for: item) }, onReveal: { reveal(item) }, onDelete: { store.delete(item) })
                                    .id(item.id)
                            }
                            SectionLabel("RECENT")
                        }
                        ForEach(filteredItems.filter { !(filter == .all && query.isEmpty && $0.isFavorite) }) { item in
                            ClipboardHistoryCard(item: item, query: query, isSelected: selectedID == item.id, isBatchSelected: selectedIDs.contains(item.id), isRevealed: revealSensitiveIDs.contains(item.id), groups: store.settings.groups, onSelect: { selectedID = item.id }, onToggleSelection: { toggleBatchSelection(item) }, onPaste: { paste(item) }, onFavorite: { store.toggleFavorite(item) }, onGroup: { store.setGroup($0, for: item) }, onEdit: { beginEditing(item) }, onRename: { aliasItem = item; aliasText = item.alias ?? "" }, onPasswordManager: { passwordManagerItem = item; passwordManagerURL = item.passwordManagerURL ?? "" }, onOpenPasswordManager: { store.openPasswordManager(for: item) }, onReveal: { reveal(item) }, onDelete: { store.delete(item) })
                                .id(item.id)
                        }
                    }
                    .padding(Design.Space.md)
                    .animation(PasteXStyle.gentleMotion, value: store.items.map(\.id))
                }
                .scrollIndicators(.hidden)
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
