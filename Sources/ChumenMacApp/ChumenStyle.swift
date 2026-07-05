import SwiftUI

// Shared app visual tokens. Keeping these outside ContentView prevents every extracted screen
// from inventing its own radius, surface, and muted-text rules.
enum ChumenStyle {
    static let radius: CGFloat = 8
    // Dashboard height is intentionally scaled without changing the horizontal measure.
    // The assistant rail is scoped to the dashboard because dense work pages need the full 1080-pt
    // window width for lists, editors, and table-like rows.
    static let dashboardVerticalScale: CGFloat = 1.20
    static let aiSidebarWidth: CGFloat = 320
    static let aiCollapsedSidebarWidth: CGFloat = 46
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
