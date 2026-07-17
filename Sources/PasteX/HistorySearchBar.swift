import SwiftUI

struct HistorySearchBar: View {
    @Binding var query: String
    var focus: FocusState<Bool>.Binding
    var compact = false

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Search clipboard history", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused(focus)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
            KeyHint(value: "⌘K")
        }
        .padding(.horizontal, compact ? 10 : 12)
        .padding(.vertical, compact ? 7 : 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: PasteXStyle.inputRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PasteXStyle.inputRadius, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.22), lineWidth: 0.5)
        }
    }
}
