import AppKit
import SwiftUI

/// The wording and line rules of the two toasts (RD-R17; the mock's `toast`, `errToast` and `failToast`). Pure apart from
/// measuring with AppKit's text layout.
enum ToastText {
    /// A refused write shows at most this many lines until Details opens it (RD-R17).
    static let refusedLineLimit = 3

    static let nothingChanged = "Nothing changed."

    /// The reassurance comes first, so a clamped toast still says nothing changed: "Couldn't remove x: y. Nothing changed."
    /// reads "Nothing changed. Couldn't remove x: y." A message without it is left as it is.
    static func refusedMessage(_ message: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasSuffix(nothingChanged), trimmed != nothingChanged else { return trimmed }
        let rest = trimmed.dropLast(nothingChanged.count).trimmingCharacters(in: .whitespaces)
        return "\(nothingChanged) \(rest)"
    }

    /// How many lines `text` takes at `width` in `role`, as the toast lays it out (word wrapping, the role's line box).
    static func lineCount(_ text: String, width: CGFloat, role: TypeRole = .bodyText) -> Int {
        guard !text.isEmpty else { return 0 }
        guard width > 0 else { return Int.max }
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        style.minimumLineHeight = role.lineHeight
        style.maximumLineHeight = role.lineHeight
        let attributed = NSAttributedString(string: text, attributes: [.font: role.nsFont, .paragraphStyle: style])
        let box = attributed.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                          options: [.usesLineFragmentOrigin, .usesFontLeading])
        // A hair of slack: AppKit's height can land a fraction above a whole number of lines.
        return max(1, Int((box.height / role.lineHeight - 0.05).rounded(.up)))
    }

    /// Details is offered only when the message needs more than the limit; before the width is known (0) it is not.
    static func needsDetails(_ text: String, width: CGFloat, role: TypeRole = .bodyText) -> Bool {
        width > 0 && lineCount(text, width: width, role: role) > refusedLineLimit
    }

    /// The line limit drawn: 3, or none once Details is open.
    static func lineLimit(expanded: Bool) -> Int? { expanded ? nil : refusedLineLimit }

    /// What VoiceOver announces: a write politely, a refusal at high priority (RD-R16 "Announcements").
    @MainActor
    static func announce(_ message: String, refused: Bool) {
        var spoken = AttributedString(message)
        spoken.accessibilitySpeechAnnouncementPriority = refused ? .high : .default
        AccessibilityNotification.Announcement(spoken).post()
    }
}
