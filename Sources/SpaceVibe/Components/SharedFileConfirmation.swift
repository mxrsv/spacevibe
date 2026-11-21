import SwiftUI

/// The anchored confirmation when a lit logo or tile is turned off and its file is read by other CLIs too (RD-R11 "Shared
/// files"; the mock's `tglPopover`): it names the file(s), every other CLI that loses the item, and the CLIs that can keep it
/// through their own folder; then Cancel, `Remove for N CLIs` (red tint) and, when someone can keep it, `Copy to …, then
/// remove`. Pure wording in `SharedFileConfirmation.Wording`.
struct SharedFileConfirmation: View {
    struct Wording: Hashable, Sendable {
        /// The CLI being turned off.
        let cli: String
        /// The files that would go, shown in mono.
        let files: [String]
        /// Every CLI that loses the item, `cli` included.
        let losers: [String]
        /// The CLIs that lose it but whose own folder is not among the files, so they can keep a copy.
        let savable: [String]
        /// Short names for the copy button ("Cursor", "Amp").
        var savableShort: [String] = []

        var others: [String] { losers.filter { $0 != cli } }

        var sentence: String {
            let what = files.joined(separator: " and ")
            let verb = files.count > 1 ? "are" : "is"
            let get = others.count > 1 ? "get" : "gets"
            var text = "\(what) \(verb) also how \(CLINames.sentence(others)) \(get) it. Removing it from \(cli) removes it for "
                + "\(others.count > 1 ? "them" : "it") too."
            if !savable.isEmpty {
                text += " \(CLINames.sentence(savable)) can keep it with \(savable.count > 1 ? "their own copies" : "its own copy")."
            }
            return text
        }

        var removeTitle: String { "Remove for \(NumberWording.plural(losers.count, "CLI"))" }

        var copyTitle: String? {
            savable.isEmpty ? nil : "Copy to \((savableShort.isEmpty ? savable : savableShort).joined(separator: ", ")) first, then remove"
        }
    }

    let wording: Wording
    let cancel: () -> Void
    let removeForAll: () -> Void
    var copyThenRemove: (() -> Void)?

    var body: some View {
        PopoverPanel(label: "Turn off \(wording.cli)", close: cancel) {
            Text(wording.sentence)
                .typeRole(.quiet)
                .foregroundStyle(ColorRole.ink2)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: SpaceRole.step6) {
                Button(action: cancel) { Text("Cancel").frame(maxWidth: .infinity, alignment: .leading) }
                    .buttonStyle(PushButtonStyle(.quiet, size: .small))
                    .keyboardShortcut(.defaultAction)
                    .focusEffectDisabled()
                Button(action: removeForAll) { Text(wording.removeTitle).frame(maxWidth: .infinity, alignment: .leading) }
                    .buttonStyle(PushButtonStyle(.destructive, size: .small))
                    .focusEffectDisabled()
                if let title = wording.copyTitle, let copyThenRemove {
                    Button(action: copyThenRemove) { Text(title).frame(maxWidth: .infinity, alignment: .leading) }
                        .buttonStyle(PushButtonStyle(.control, size: .small))
                        .focusEffectDisabled()
                }
            }
        }
    }
}
