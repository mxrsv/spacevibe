import SwiftUI

/// The Activity inspector (the mock's `sessInspector` and `failInspector`): each tab has its own. Nothing selected shows the
/// frame's "Select a row" state.
struct ActivityInspector: View {
    let context: ActivityPageContext

    var body: some View {
        let data = context.data()
        if let row = data.selectedSession {
            ActivitySessionInspector(context: context, row: row)
        } else if let row = data.selectedFailure {
            ActivityFailureInspector(context: context, row: row)
        } else {
            PageEmptyState(icon: .sidebarSimple, text: "Select a row to see its details.")
        }
    }
}

/// One session: its title with the CLI's logo, the facts, the open tool call, the "answer in the terminal" note for a wait,
/// and Show Terminal (RD36: the app that runs the session comes to the front through `HostAppResolver`; with none, as in
/// tmux, screen or ssh, the button is disabled and says "Terminal app not found") and Copy Session Id.
struct ActivitySessionInspector: View {
    let context: ActivityPageContext
    let row: ActivitySessionRow
    @Environment(ToastCenter.self) private var toasts

    var body: some View {
        VStack(alignment: .leading, spacing: SpaceRole.step16) {
            InspectorTitle(row.session.title, sub: row.cliName) {
                CLILogo(CLIIdentity(id: row.session.cli.rawValue, name: row.cliName), size: SizeRole.logo20)
            }
            KeyValueList(facts: row.facts)
            InspectorSection("Current tool") {
                if let tool = row.toolBlock { CommandBlock(tool) } else { InspectorNote(row.noToolNote) }
            }
            if row.isWaiting {
                InspectorNote(ActivitySessionInspector.answerNote, icon: .infoFill)
            }
            InspectorActions(actions: actions)
        }
    }

    static let answerNote = "Answer in the terminal. SpaceVibe only shows that it is waiting."

    private var actions: [InspectorAction] {
        var list: [InspectorAction] = []
        if row.isLive {
            let host = context.state.host(of: row)
            list.append(InspectorAction(id: "terminal", title: host == nil ? ActivityPageState.noHost : "Show Terminal",
                                        icon: .terminalWindow, isEnabled: host != nil) {
                context.state.showTerminal(row, toasts: toasts)
            })
        }
        list.append(InspectorAction(id: "copyID", title: "Copy Session Id", icon: .copy) {
            context.state.copySessionID(row, toasts: toasts)
        })
        return list
    }
}

/// One failure: the command (a Hook by its script) with its kind icon, the kind and CLI, the whole command, the facts,
/// Copy Command and Dismiss.
struct ActivityFailureInspector: View {
    let context: ActivityPageContext
    let row: ActivityFailureRow
    @Environment(ToastCenter.self) private var toasts

    var body: some View {
        VStack(alignment: .leading, spacing: SpaceRole.step16) {
            InspectorTitle(row.title, sub: row.kindLine, isMono: true) {
                FrameGlyph(row.icon, side: SizeRole.icon20, ink: ColorRole.ink3)
            }
            CommandBlock(row.failure.title)
            KeyValueList(facts: row.facts)
            InspectorActions(actions: [
                InspectorAction(id: "copyCommand", title: "Copy Command", icon: .copy) { context.state.copyCommand(row, toasts: toasts) },
                InspectorAction(id: "dismiss", title: "Dismiss", isQuiet: true) {
                    context.state.dismiss(row, toasts: toasts, router: context.model.router)
                },
            ])
        }
    }
}
