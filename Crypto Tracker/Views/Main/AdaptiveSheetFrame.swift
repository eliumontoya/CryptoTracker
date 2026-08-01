import SwiftUI

// MARK: - macOS-only sheet sizing

// Forms and sheets were designed with hardcoded minimum sizes for macOS windows.
// On iOS those minimums (500x700, 300x200) overflow the screen and break the
// layout, so they are dropped entirely; macOS keeps its exact constraints.
extension View {
    /// Applies macOS-only minimum/ideal sizing. On iOS the constraints are omitted.
    /// Defaults reproduce `.frame(minWidth: 500, minHeight: 700)` on macOS.
    @ViewBuilder
    func adaptiveSheetFrame(
        minWidth: CGFloat? = 500,
        idealWidth: CGFloat? = nil,
        maxWidth: CGFloat? = nil,
        minHeight: CGFloat? = 700,
        idealHeight: CGFloat? = nil,
        maxHeight: CGFloat? = nil
    ) -> some View {
        #if os(macOS)
        self.frame(
            minWidth: minWidth,
            idealWidth: idealWidth,
            maxWidth: maxWidth,
            minHeight: minHeight,
            idealHeight: idealHeight,
            maxHeight: maxHeight
        )
        #else
        self
        #endif
    }
}
