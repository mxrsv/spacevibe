import SwiftUI

/// What the Stop alert says (RD-R16; the mock's `stopAlert`; GLOSSARY "Stop": the one write with no Undo names the pid and
/// the consequence first). Pure, so the wording and the cap are tested.
struct StopAlertText: Hashable, Sendable {
    struct Session: Hashable, Sendable {
        let title: String
        let pid: Int32
        /// The CLI's name, for the line.
        let cli: String
    }

    let sessions: [Session]

    /// `Stop “Fix flaky checkout test”?` for one, `Stop 3 sessions?` for several.
    var title: String {
        if sessions.count == 1 { return "Stop “\(sessions[0].title)”?" }
        return "Stop \(NumberWording.plural(sessions.count, "session"))?"
    }

    /// One line per session, at most 5, then "and N more sessions".
    var lines: [String] {
        let capped = CappedList(sessions)
        return capped.shown.map { "\($0.cli) · \($0.title) · pid \($0.pid)" } + [capped.moreLine(one: "session")].compactMap { $0 }
    }

    static let consequence = "Each process gets a stop signal after its pid is checked again. The session ends and anything "
        + "it has not saved is lost. This can’t be undone."

    /// The lines, then the consequence.
    var message: String { (lines + [Self.consequence]).joined(separator: "\n") }

    /// `Stop Session 48211`, `Stop 3 Sessions`.
    var confirmTitle: String {
        sessions.count == 1 ? "Stop Session \(sessions[0].pid)" : "Stop \(NumberWording.count(sessions.count)) Sessions"
    }
}

extension View {
    /// The Stop alert (DS-R10: a system alert with a destructive role, RD-R9): the system draws and places it, Esc closes it,
    /// and the focus returns to what opened it. Cancel is the default (Return) and Stop is destructive and never the default
    /// (RD-R16). Whether the system alert keeps Return on Cancel with a destructive button beside it is checked live in RB-V2.
    func stopAlert(isPresented: Binding<Bool>, text: StopAlertText, stop: @escaping () -> Void) -> some View {
        alert(text.title, isPresented: isPresented) {
            Button("Cancel", role: .cancel) {}
                .keyboardShortcut(.defaultAction)
            Button(text.confirmTitle, role: .destructive, action: stop)
        } message: {
            Text(text.message)
        }
        .dialogSeverity(.critical)
    }
}
