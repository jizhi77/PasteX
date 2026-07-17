import SwiftUI

struct FloatingHistorySurface<Content: View>: View {
    let content: Content
    @State private var isPresented = false

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.34), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.14), radius: 24, x: 0, y: 12)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .opacity(isPresented ? 1 : 0)
            .scaleEffect(isPresented ? 1 : 0.96)
            .animation(PasteXStyle.motion, value: isPresented)
            .onReceive(NotificationCenter.default.publisher(for: .pasteXHistoryPresentation)) { notification in
                withAnimation(PasteXStyle.motion) { isPresented = (notification.object as? Bool) ?? false }
            }
    }
}
