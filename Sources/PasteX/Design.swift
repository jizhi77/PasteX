import SwiftUI

enum Design {
    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
    }

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
    }

    enum Color {
        static let panel = SwiftUI.Color(nsColor: .windowBackgroundColor)
        static let elevated = SwiftUI.Color(nsColor: .controlBackgroundColor)
        static let selected = SwiftUI.Color.accentColor.opacity(0.16)
        static let muted = SwiftUI.Color.secondary
        static let separator = SwiftUI.Color(nsColor: .separatorColor).opacity(0.65)
        static let pause = SwiftUI.Color.orange
    }
}

struct KeyHint: View {
    let value: String

    var body: some View {
        Text(value)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(Design.Color.muted)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Design.Color.elevated, in: RoundedRectangle(cornerRadius: 4))
    }
}
