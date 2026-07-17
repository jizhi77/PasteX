import SwiftUI

struct SettingsView: View {
    @Bindable var store: ClipboardStore
    @State private var newGroup = ""
    @State private var renamedGroup: String?
    @State private var groupName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Design.Space.lg) {
                header
                SettingsSection("Quick access") {
                    Picker("Global shortcut", selection: binding(\.hotKey)) {
                        ForEach(HotKeyChoice.allCases) { Text($0.title).tag($0) }
                    }
                    .onChange(of: store.settings.hotKey) { _, _ in HotKeyMonitor.shared.register(choice: store.settings.hotKey) }
                    Toggle("Show compact menu near the focused cursor", isOn: binding(\.quickMenuNearCursor))
                    Text("PasteX falls back to the centre of the active display when macOS cannot read a focused cursor position.")
                        .font(.caption).foregroundStyle(Design.Color.muted)
                }
                SettingsSection("History retention") {
                    Picker("Keep history", selection: binding(\.retentionPeriod)) {
                        ForEach(RetentionPeriod.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Maximum item size", selection: binding(\.maximumTextLength)) {
                        Text("2 KB").tag(2_000); Text("10 KB").tag(10_000); Text("50 KB").tag(50_000)
                    }
                    Picker("Maximum history items", selection: binding(\.maximumItems)) {
                        Text("100").tag(100); Text("500").tag(500); Text("1,000").tag(1_000)
                    }
                    Text("The oldest non-pinned entries are removed automatically when a limit is reached. Pinned items are retained.")
                        .font(.caption).foregroundStyle(Design.Color.muted)
                }
                SettingsSection("Privacy and security") {
                    Toggle("Record copied text", isOn: Binding(get: { !store.settings.isPaused }, set: { $0 ? store.resumeRecording() : store.pause(for: .indefinitely) }))
                    Toggle("Keep detected sensitive content temporarily", isOn: binding(\.saveSensitiveItems))
                    Picker("Sensitive content expires after", selection: binding(\.sensitiveExpiry)) {
                        ForEach(SensitiveExpiry.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Clear the system clipboard 30 seconds after sensitive paste", isOn: binding(\.clearPasteboardAfterSensitivePaste))
                    Toggle("Strict masking for screen sharing", isOn: binding(\.strictPrivacyMode))
                    Text("Sensitive content, pinned items, and all settings are encrypted locally with a key stored in your Mac keychain. PasteX never syncs history to a server.")
                        .font(.caption).foregroundStyle(Design.Color.muted)
                }
                SettingsSection("Groups, pinned items, and snippets") {
                    HStack { TextField("New group", text: $newGroup); Button("Add") { store.addGroup(named: newGroup); newGroup = "" }.disabled(newGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                    ForEach(store.settings.groups, id: \.self) { group in
                        HStack { Text(group); Spacer(); Button("Rename") { renamedGroup = group; groupName = group }; Button("Delete", role: .destructive) { store.deleteGroup(group) } }
                    }
                    Toggle("Enable typed snippet expansion", isOn: binding(\.snippetsEnabled))
                    Text("Assign a trigger such as ;addr from an item’s menu. Accessibility permission is required for system-wide expansion.")
                        .font(.caption).foregroundStyle(Design.Color.muted)
                }
                SettingsSection("Paste and integrations") {
                    Toggle("Paste text without formatting by default", isOn: binding(\.defaultPastePlainText))
                    Text("Password-manager content is ignored by default. You can optionally add an open link to a pinned item instead of storing a password.")
                        .font(.caption).foregroundStyle(Design.Color.muted)
                    Text("Sync & backup: local-only in this release. Encrypted export will be added in a future update.")
                        .font(.caption).foregroundStyle(Design.Color.muted)
                }
                HStack { Spacer(); Button("Restore Defaults", role: .destructive) { store.restoreDefaults() } }
            }
            .padding(Design.Space.lg)
        }
        .frame(minWidth: 520, minHeight: 580)
        .background(.ultraThinMaterial)
        .alert("Rename Group", isPresented: Binding(get: { renamedGroup != nil }, set: { if !$0 { renamedGroup = nil } })) {
            TextField("Name", text: $groupName)
            Button("Cancel", role: .cancel) { renamedGroup = nil }
            Button("Save") { if let renamedGroup { store.replaceGroup(renamedGroup, with: groupName) }; renamedGroup = nil }
        }
    }

    private var header: some View { VStack(alignment: .leading, spacing: 5) { Text("PasteX Settings").font(.system(size: 20, weight: .medium)); Text("Local-first clipboard controls. Changes apply immediately unless noted.").font(.system(size: 12)).foregroundStyle(.secondary) } }
    private func binding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> { Binding(get: { store.settings[keyPath: keyPath] }, set: { store.settings[keyPath: keyPath] = $0 }) }
}
