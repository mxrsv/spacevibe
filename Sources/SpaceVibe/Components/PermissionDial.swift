import SwiftUI

/// The three-step permission dial of a Rules capability row and a rule's inspector (the mock's `.dial`): Allow, Ask and
/// Deny on the small `FrameSegmentedControl` (DS-R10 has one segmented control), so it draws exactly as the Clean age control
/// does: the chosen step on the neutral selection fill in `quietMedium` `ink` (never the primary, RD-R9), the others `quiet`
/// on the control fill. No step is chosen while nothing is set. A `locked` dial (a Mixed capability cell, which the engine
/// refuses to write) shows one chosen step with the lock and the word instead of buttons. It is a radio group for VoiceOver:
/// each step reads its title and whether it is chosen. Keyboard focus is the RD29 bar, not a ring (D57).
struct PermissionDial: View {
    /// The chosen step; nil when no rule sets one.
    let selection: CoreVerdict?
    /// What the dial chooses, for VoiceOver ("Run commands", "Permission").
    let label: String
    /// The word a locked dial shows ("Mixed"); nil for a dial that can be pressed.
    var lockedWord: String?
    /// The step a write is moving the rule to (FE-L2: pending at the control): it shows the pending mark, and no step takes a
    /// press until the write is done.
    var pending: CoreVerdict?
    /// The track spans the width it is given, steps at its leading end (the mock's dial in the 190 grid column of a
    /// capability row); otherwise it hugs its steps (the inspector).
    var fillsWidth = false
    let pick: (CoreVerdict) -> Void

    init(selection: CoreVerdict?, label: String, lockedWord: String? = nil, pending: CoreVerdict? = nil, fillsWidth: Bool = false,
         pick: @escaping (CoreVerdict) -> Void) {
        self.selection = selection
        self.label = label
        self.lockedWord = lockedWord
        self.pending = pending
        self.fillsWidth = fillsWidth
        self.pick = pick
    }

    /// Whether a press on a step reaches `pick`: never while a change is pending. Pure, for the tests.
    static func takesPress(pending: CoreVerdict?) -> Bool { FrameSegmentedControl.takesPress(pending: pending?.rawValue) }

    /// The dial's steps as segments, Allow, Ask, Deny.
    static let segments = CoreVerdict.allCases.map { FrameSegment(id: $0.rawValue, title: title($0)) }

    var body: some View {
        if let lockedWord {
            LockedDial(word: lockedWord, label: label, fillsWidth: fillsWidth)
        } else {
            FrameSegmentedControl(segments: Self.segments, selection: selection?.rawValue, label: label, size: .small,
                                  pending: pending?.rawValue, fillsWidth: fillsWidth) { id in
                if let verdict = CoreVerdict(rawValue: id), Self.takesPress(pending: pending) { pick(verdict) }
            }
        }
    }

    /// "Allow", "Ask", "Deny".
    static func title(_ verdict: CoreVerdict) -> String {
        switch verdict {
        case .allow: "Allow"
        case .ask: "Ask"
        case .deny: "Deny"
        }
    }

    /// What VoiceOver reads for the whole dial: "Run commands, Ask"; "Network, not set".
    static func spoken(label: String, selection: CoreVerdict?) -> String {
        "\(label), \(selection.map(title) ?? "not set")"
    }
}

/// A Mixed capability cell: the small control's track with one chosen step that holds the lock and the word, no buttons.
private struct LockedDial: View {
    let word: String
    let label: String
    let fillsWidth: Bool

    var body: some View {
        let track = CornerRoleShape(FrameSegmentedControl.Size.small.trackCorner(.solid))
        HStack(spacing: SpaceRole.step4) {
            FrameGlyph(.lockSimple, side: SizeRole.icon12, ink: ColorRole.ink)
            Text(word).typeRole(.quietMedium)
        }
        .foregroundStyle(ColorRole.ink)
        .padding(.horizontal, SpaceRole.step8)
        .frame(height: SizeRole.segmentSmall)
        .background(CornerRoleShape(FrameSegmentedControl.Size.small.segmentCorner(.solid)).fill(ColorRole.chosenSegmentFill))
        .padding(SizeRole.segmentedInset)
        .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: .leading)
        .frame(height: SizeRole.controlSmall)
        .background(track.fill(ColorRole.controlFill))
        .overlay(track.strokeBorder(ColorRole.controlEdge, lineWidth: StrokeRole.hairline))
        .fixedSize(horizontal: !fillsWidth, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(word), read only")
    }
}
