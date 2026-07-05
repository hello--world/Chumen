import SwiftUI

// Shared app visual tokens. Keeping these outside ContentView prevents every extracted screen
// from inventing its own radius, surface, and muted-text rules.
enum ChumenStyle {
    static let radius: CGFloat = 8
    // Wide desktop windows should still read like a native utility, not a web dashboard.
    // Keep primary app chrome and dashboard content on one shared measure so the eye
    // does not have to scan from the far-left window edge to the far-right edge.
    static let shellContentMaxWidth: CGFloat = 1320
    static let shellContentWidthRatio: CGFloat = 0.80
    static let shellContentMinWidth: CGFloat = 760
    static let dashboardVerticalScale: CGFloat = 1.20

    static func shellContentWidth(for availableWidth: CGFloat) -> CGFloat {
        let safeWidth = max(0, availableWidth)
        guard safeWidth > shellContentMinWidth else { return safeWidth }
        return min(shellContentMaxWidth, max(shellContentMinWidth, safeWidth * shellContentWidthRatio))
    }
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
