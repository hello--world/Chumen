import SwiftUI

// Shared operation-color vocabulary. Views select an action's meaning instead of a raw color;
// a future user-configurable palette only needs to replace this resolver.
enum ChumenActionTone {
    case primary
    case refresh
    case update
    case test
    case clear
    case help
    case destructive

    var color: Color {
        ChumenActionPalette.color(for: self)
    }
}

enum ChumenActionPalette {
    static func color(for tone: ChumenActionTone) -> Color {
        switch tone {
        case .primary:
            ChumenStyle.accent
        case .refresh:
            Color(red: 0.10, green: 0.43, blue: 0.78)
        case .update:
            Color(red: 0.02, green: 0.57, blue: 0.64)
        case .test:
            Color(red: 0.02, green: 0.57, blue: 0.64)
        case .clear, .help:
            Color(red: 0.82, green: 0.20, blue: 0.24)
        case .destructive:
            Color(red: 0.82, green: 0.20, blue: 0.24)
        }
    }
}

extension View {
    func chumenActionSurface(_ tone: ChumenActionTone, cornerRadius: CGFloat = 6) -> some View {
        let color = tone.color
        return foregroundStyle(Color.primary)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(color.opacity(0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(color.opacity(0.14))
            )
    }
}
