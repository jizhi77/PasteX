import SwiftUI

struct SettingsView: View {
    @Bindable var store: ClipboardStore
    @State private var newGroup = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Space.lg) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings").font(.system(size: 20, weight: .semibold))
                Text("Local storage and recording controls.").font(.system(size: 12)).foregroundStyle(Design.Color.muted)
            }
            Form {
                Toggle("Record copied text", isOn: Binding(get: { !store.settings.isRecordingPaused }, set: { store.settings.isRecordingPaused = !$0 }))
                Picker("Keep history", selection: $store.settings.retentionDays) {
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                    Text("1 year").tag(365)
                }
                Picker("Maximum text size", selection: $store.settings.maximumTextLength) {
                    Text("2 KB").tag(2_000)
                    Text("10 KB").tag(10_000)
                    Text("50 KB").tag(50_000)
                }
                Picker("Maximum history items", selection: $store.settings.maximumItems) {
                    Text("100").tag(100)
                    Text("500").tag(500)
                    Text("1,000").tag(1_000)
                }
            }
            VStack(alignment: .leading, spacing: Design.Space.xs) {
                Text("Groups").font(.system(size: 13, weight: .semibold))
                HStack {
                    TextField("New group", text: $newGroup)
                    Button("Add") { store.addGroup(named: newGroup); newGroup = "" }
                        .disabled(newGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Text(store.settings.groups.joined(separator: "  ·  "))
                    .font(.system(size: 11))
                    .foregroundStyle(Design.Color.muted)
            }
            Spacer()
            Text("PasteX stores clipboard history only on this Mac.")
                .font(.system(size: 11))
                .foregroundStyle(Design.Color.muted)
        }
        .padding(Design.Space.lg)
        .frame(minWidth: 400, minHeight: 330)
    }
}
