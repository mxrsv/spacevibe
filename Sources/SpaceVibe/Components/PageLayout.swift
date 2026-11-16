import SwiftUI

extension View {
    /// The window's ground (`bgSide`) behind the shell and Settings.
    func pageBackground() -> some View {
        background(Palette.bgSide)
    }
}

/// Vertical rhythm between blocks on a page: nearness says what belongs together.
enum Rhythm {
    /// Between tiles in one row (Settings > Theme).
    static let tiles = Space.s8

    // Spec, "Rhythm and sizes (D66)": two levels, small inside a group, large between groups.
    /// The content edge: canvas padding and the tab head's side padding.
    static let edge = Space.s32
    /// Between cards, and between stacked small cards.
    static let card = Space.s24
    /// Above a band (none above the first).
    static let group = Space.s32
    /// The sidebar's padding at the sides and the bottom.
    static let side = Space.s16
}
