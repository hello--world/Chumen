import SwiftUI

// Shared app visual tokens. Keeping these outside ContentView prevents every extracted screen
// from inventing its own radius, surface, and muted-text rules.
enum ChumenStyle {
    static let radius: CGFloat = 8
    // Dashboard controls are intentionally a little taller than table/form pages because the
    // overview doubles as the agent workspace and should read as a command surface, not a dense list.
    static let dashboardVerticalScale: CGFloat = 1.20
    static let accent = Color(red: 0.02, green: 0.48, blue: 0.38)
    static let pageBackground = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .textBackgroundColor)
    static let groupedSurface = Color(nsColor: .controlBackgroundColor)
    static let controlFill = Color.primary.opacity(0.065)
    static let identityFill = Color.primary.opacity(0.035)
    static let border = Color(nsColor: .separatorColor).opacity(0.30)
    static let mutedText = Color(nsColor: .secondaryLabelColor)
    static let softShadow = Color.black.opacity(0.025)
}
