import SwiftUI

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(.primary)
            content
                .font(.system(size: 13))
        }
        .padding(16)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: PasteXStyle.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PasteXStyle.cardRadius, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.2), lineWidth: 0.5)
        }
    }
}
