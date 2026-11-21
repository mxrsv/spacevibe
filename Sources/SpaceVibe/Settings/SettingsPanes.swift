import AppKit
import SwiftUI

/// What every pane of the Settings window reads and how it reports back: the preferences it edits, the store's facts, the
/// clock, and the window's toast (a refused setting, a copied command) and Journal window.
@MainActor
struct SettingsPaneContext {
    let facts: SettingsFacts
    let now: Date
    let cli: CLIPreferences
    let glance: GlancePreferences
    let countdown: LimitsCountdownPreferences
    let loginItem: LoginItem
    /// The data folder Settings › Data shows (`SettingsDataWording.dataFolder()`).
    let dataFolder: URL
    let toast: (String, ToastTone) -> Void
    let showJournal: () -> Void
}

/// The open pane's body (the mock's `.sbody`): its groups top to bottom, 20 apart, at least the window's body height.
struct SettingsPaneBody: View {
    let pane: SettingsPane
    let context: SettingsPaneContext

    var body: some View {
        VStack(alignment: .leading, spacing: SpaceRole.step20) {
            switch pane {
            case .general: SettingsGeneralPane(context: context)
            case .clis: SettingsCLIsPane(context: context)
            case .limits: SettingsLimitsPane(context: context)
            case .data: SettingsDataPane(context: context)
            case .updates: SettingsUpdatesPane(context: context)
            }
        }
        .padding(.top, SpaceRole.step8)
        .padding(.horizontal, SpaceRole.step24)
        .padding(.bottom, SpaceRole.step24)
        .frame(maxWidth: .infinity, minHeight: FrameRole.settingsBodyMinHeight, alignment: .topLeading)
    }
}

// MARK: General

/// Open at login, the theme switch (D70, RD21) and the Session widget switch (GW18). Theme and widget are the v5 stores
/// (`AppearanceStore`, `GlancePreferences`), so both shells keep one stored value each.
private struct SettingsGeneralPane: View {
    let context: SettingsPaneContext
    @Environment(AppearanceStore.self) private var appearance

    var body: some View {
        let login = context.loginItem.status
        RowGroup {
            SettingsRow(LoginItemWording.title, detail: Self.loginDetail(login), index: 0) {
                if login == .needsApproval {
                    Button { context.loginItem.openSystemSettings() } label: {
                        PushButtonLabel(LoginItemWording.openSettings, size: .small)
                    }
                    .buttonStyle(PushButtonStyle(.control, size: .small))
                    .focusEffectDisabled()
                }
                FrameSwitch(LoginItemWording.title, isOn: login.isOn) {
                    if let refusal = context.loginItem.set(!login.isOn) { context.toast(refusal, .danger) }
                }
                .disabled(!login.canChange)
            }
            SettingsRow("Appearance", index: 1) {
                FrameSegmentedControl(segments: ThemeSetting.allCases.map { FrameSegment(id: $0.rawValue, title: $0.title) },
                                      selection: appearance.theme.rawValue, label: "Appearance") { id in
                    if let theme = ThemeSetting(rawValue: id) { appearance.theme = theme }
                }
            }
            SettingsRow(SettingsWording.glanceWidget, detail: Self.widgetDetail, index: 2) {
                FrameSwitch(SettingsWording.glanceWidget, isOn: context.glance.isEnabled) { context.glance.isEnabled.toggle() }
            }
        }
        .onAppear { context.loginItem.refresh() }
    }

    static let widgetDetail = "A small strip over every app that shows running and waiting sessions; drag it to any corner or edge"

    static func loginDetail(_ status: LoginItemStatus) -> String {
        switch status {
        case .off, .on: LoginItemWording.detail
        case .needsApproval: LoginItemWording.needsApproval
        case .unavailable(let reason): reason
        }
    }
}

// MARK: CLIs

/// Show and Balance per CLI (RB-R8, "Pinning", "Show guard"), in registry order, then the footnote.
private struct SettingsCLIsPane: View {
    let context: SettingsPaneContext

    var body: some View {
        let registry = context.facts.registry
        let rows = SettingsCLIRow.rows(registry: registry, preferences: context.cli)
        if rows.isEmpty {
            StatusBanner(.problem(.attention), title: "No CLIs yet", detail: "SpaceVibe lists the CLIs once the main window has read them.")
        } else {
            RowGroup {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    SettingsCLIRowView(row: row, index: index, registry: registry, context: context)
                }
            }
        }
        SettingsFootnote(SettingsCLIRow.footnote(pinCount: context.cli.pins(in: registry).count))
    }
}

private struct SettingsCLIRowView: View {
    let row: SettingsCLIRow
    let index: Int
    let registry: [CoreRegistryCLI]
    let context: SettingsPaneContext

    var body: some View {
        SettingsRow(row.cli.name, detail: row.supports, index: index, lead: { CLILogo(row.cli) }) {
            Text("Show").typeRole(.quiet).foregroundStyle(ColorRole.ink3).accessibilityHidden(true)
            FrameSwitch("Show \(row.cli.name)", isOn: row.isShown) {
                if let refusal = context.cli.setShown(!row.isShown, for: row.id, in: registry) {
                    context.toast(SettingsCLIRow.refusal(refusal, name: row.cli.name), .danger)
                }
            }
            .disabled(!row.canChangeShow)
            Text("Balance").typeRole(.quiet).foregroundStyle(ColorRole.ink3).accessibilityHidden(true)
            FrameSwitch("Compare \(row.cli.name) in Balance", isOn: row.isPinned) {
                if let refusal = context.cli.setPinned(!row.isPinned, for: row.id, in: registry) {
                    context.toast(SettingsCLIRow.refusal(refusal, name: row.cli.name), .danger)
                }
            }
            .disabled(!row.canChangePin)
        }
    }
}

// MARK: Limits

/// The Weekly countdown lead (RD33, `LimitsCountdownPreferences`: the v5 key) and the status-line capture (RD24): the app
/// copies the commands, never runs them (S-R4).
private struct SettingsLimitsPane: View {
    let context: SettingsPaneContext

    var body: some View {
        RowGroup {
            SettingsRow(SettingsLimitsWording.weeklyCountdown, detail: SettingsLimitsWording.weeklyCountdownDetail, index: 0) {
                FrameSegmentedControl(segments: WeeklyCountdownLead.allCases.map { FrameSegment(id: String($0.rawValue), title: $0.title) },
                                      selection: String(context.countdown.weeklyLead.rawValue),
                                      label: SettingsLimitsWording.weeklyCountdown) { id in
                    if let lead = Int(id).flatMap(WeeklyCountdownLead.init(rawValue:)) { context.countdown.weeklyLead = lead }
                }
            }
            SettingsRow(SettingsLimitsWording.capture, detail: SettingsLimitsWording.snapshot(context.facts, now: context.now), index: 1) {
                copyButton(SettingsLimitsWording.copyInstall, remove: false, kind: .control)
                copyButton(SettingsLimitsWording.copyRemove, remove: true, kind: .quiet)
            }
            .help(SettingsLimitsWording.failure(context.facts) ?? "")
        }
        SettingsFootnote(SettingsLimitsWording.footnote)
    }

    private func copyButton(_ title: String, remove: Bool, kind: PushButtonStyle.Kind) -> some View {
        Button {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(SettingsLimitsWording.command(remove: remove), forType: .string)
            context.toast(LimitsCards.copiedMessage, .info)
        } label: {
            PushButtonLabel(title, icon: .copy, size: .small)
        }
        .buttonStyle(PushButtonStyle(kind, size: .small))
        .focusEffectDisabled()
    }
}

// MARK: Data

/// The data folder, the Journal and SpaceVibe's trash, with no Empty (RD25).
private struct SettingsDataPane: View {
    let context: SettingsPaneContext

    var body: some View {
        let trash = SettingsDataWording.trashFolder(in: context.dataFolder)
        let hasTrash = FileManager.default.fileExists(atPath: trash.path)
        RowGroup {
            SettingsRow(SettingsDataWording.dataFolder, detail: SettingsDataWording.shown(context.dataFolder), index: 0) {
                finderButton(context.dataFolder)
            }
            SettingsRow(SettingsDataWording.journal, detail: SettingsDataWording.journalDetail, index: 1) {
                Button(action: context.showJournal) {
                    PushButtonLabel(SettingsDataWording.showJournal, icon: .clockCounterClockwise, size: .small)
                }
                .buttonStyle(PushButtonStyle(.control, size: .small))
                .focusEffectDisabled()
            }
            SettingsRow(SettingsDataWording.trash, detail: SettingsDataWording.trashDetail, index: 2) {
                finderButton(trash)
                    .disabled(!hasTrash)
                    .help(hasTrash ? "" : SettingsDataWording.trashMissing)
            }
        }
    }

    private func finderButton(_ folder: URL) -> some View {
        Button { NSWorkspace.shared.activateFileViewerSelecting([folder]) } label: {
            PushButtonLabel(SettingsDataWording.showInFinder, icon: .folderOpen, size: .small)
        }
        .buttonStyle(PushButtonStyle(.control, size: .small))
        .focusEffectDisabled()
    }
}

// MARK: Updates

/// The version with Check Now (View Update once one is found) and Sparkle's daily check, over v5's `UpdateController`
/// (S-R5: Sparkle is the only request). Opening the pane never starts a check.
private struct SettingsUpdatesPane: View {
    let context: SettingsPaneContext
    @Environment(UpdateController.self) private var updates

    var body: some View {
        RowGroup {
            SettingsRow(SettingsUpdatesWording.version, detail: SettingsUpdatesWording.versionLine(updates, now: context.now), index: 0) {
                if case .available = updates.status {
                    Button { updates.checkForUpdates() } label: {
                        PushButtonLabel(SettingsUpdatesWording.viewUpdate, size: .small)
                    }
                    .buttonStyle(PushButtonStyle(.primary, size: .small))
                    .focusEffectDisabled()
                } else {
                    Button { updates.checkNow() } label: {
                        PushButtonLabel(SettingsUpdatesWording.checkNow, icon: .arrowClockwise, size: .small)
                    }
                    .buttonStyle(PushButtonStyle(.control, size: .small, isLoading: updates.status == .checking))
                    .focusEffectDisabled()
                    .disabled(!updates.isRunning || updates.status == .checking)
                }
            }
            SettingsRow(SettingsUpdatesWording.daily,
                        detail: SettingsUpdatesWording.unavailable(updates) ?? SettingsUpdatesWording.dailyDetail, index: 1) {
                FrameSwitch(SettingsUpdatesWording.daily, isOn: updates.automaticChecks) { updates.automaticChecks.toggle() }
                    .disabled(!updates.isRunning)
            }
        }
    }
}

// MARK: Rows

/// One Settings row (the mock's `.frow`): an optional lead, the name over a quiet line, the controls at the end; 44 high at
/// least, every other row on the zebra step, so rows group by fill, never by a line (FE-SP5).
struct SettingsRow<Lead: View, Trailing: View>: View {
    let title: String
    var detail: String?
    let index: Int
    @ViewBuilder var lead: Lead
    @ViewBuilder var trailing: Trailing

    init(_ title: String, detail: String? = nil, index: Int, @ViewBuilder lead: () -> Lead,
         @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.detail = detail
        self.index = index
        self.lead = lead()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: SpaceRole.step12) {
            lead
            VStack(alignment: .leading, spacing: 0) {
                Text(title).typeRole(.bodyText).foregroundStyle(ColorRole.ink).lineLimit(1)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .typeRole(.quiet)
                        .foregroundStyle(ColorRole.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            HStack(spacing: SpaceRole.step10) { trailing }
                .fixedSize()
        }
        .padding(.vertical, SpaceRole.step8)
        .padding(.horizontal, SpaceRole.step16)
        .frame(maxWidth: .infinity, minHeight: SizeRole.listRow, alignment: .leading)
        .rowStripe(index.isMultiple(of: 2))
        .accessibilityElement(children: .contain)
    }
}

extension SettingsRow where Lead == EmptyView {
    init(_ title: String, detail: String? = nil, index: Int, @ViewBuilder trailing: () -> Trailing) {
        self.init(title, detail: detail, index: index, lead: { EmptyView() }, trailing: trailing)
    }
}

/// The quiet sentence under a pane's group (the mock's `.q2` with 8 inside).
struct SettingsFootnote: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .typeRole(.quiet)
            .foregroundStyle(ColorRole.ink3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, SpaceRole.step8)
    }
}
