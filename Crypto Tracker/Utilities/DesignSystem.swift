import SwiftUI

/// Shared design tokens for the Crypto Tracker app.
/// Centralizes colors, typography, spacing, and reusable modifiers so the main
/// tabs and screens stay visually consistent.
enum DesignSystem {
    enum Colors {
        static let accent = Color.accentColor
        static let primaryText = Color.primary
        static let secondaryText = Color.secondary
        static let background = Color.primary.opacity(0.02)
        static let secondaryBackground = Color.gray.opacity(0.12)
        static let gain = Color.green
        static let loss = Color.red
        static let neutral = Color.gray
    }

    enum Fonts {
        static let title = Font.title.weight(.semibold)
        static let headline = Font.headline
        static let body = Font.body
        static let caption = Font.caption
        static let footnote = Font.footnote
    }

    enum Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
    }

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
    }
}

extension View {
    /// Standard card styling used across main screens.
    func cardStyle() -> some View {
        self
            .padding(DesignSystem.Spacing.medium)
            .background(DesignSystem.Colors.secondaryBackground)
            .cornerRadius(DesignSystem.Radius.medium)
    }

    /// Accent tint applied to the main tab bar and selected sidebar rows.
    func mainTabStyle() -> some View {
        self.tint(DesignSystem.Colors.accent)
    }
}
// RDD verification test — safe to remove
