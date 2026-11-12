import SwiftUI

/// How a capability summary reads: neutral states a fact, success is within safe limits, warn needs a look.
enum StatusTone: Equatable {
    case neutral, success, warn

    var icon: SpaceVibeGlyph {
        switch self {
        case .neutral: .info
        case .success: .check
        case .warn: .warning
        }
    }

    var ink: Color {
        switch self {
        case .neutral: Palette.textSecondary
        case .success: Palette.successInk
        case .warn: Palette.warnInk
        }
    }

    var tint: Color {
        switch self {
        case .neutral: Palette.surfaceRaised
        case .success: Palette.successTint
        case .warn: Palette.warnTint
        }
    }
}
