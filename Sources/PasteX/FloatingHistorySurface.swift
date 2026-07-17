import SwiftUI

struct FloatingHistorySurface<Content: View>: View {
    let content: Content
    @State private var isPresented = false

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .opacity(isPresented ? 1 : 0)
            .scaleEffect(isPresented ? 1 : 0.96)
            .animation(PasteXStyle.motion, value: isPresented)
            .onReceive(NotificationCenter.default.publisher(for: .pasteXHistoryPresentation)) { notification in
                withAnimation(PasteXStyle.motion) { isPresented = (notification.object as? Bool) ?? false }
            }
    }
}
