import AppKit
import SwiftUI

/// `SPACEVIBE_SHOT_SCREEN=settings`: Settings over the demo shell in both appearances, every Update state, the Large font
/// size, and the demo tabs at Large, where the fixed text columns would truncate first. Synthetic data only; nothing is
/// read or saved, and the updater never starts. The Session widget switch reads a throwaway defaults suite (on, its first-run
/// value), never the machine's own, so the shots are the same on every machine.
@MainActor
enum SettingsShots {
    private static let glanceSuite = "dev.spacevibe.shots.glance.\(UUID().uuidString)"

    static func run(into directory: URL) throws {
        guard let glanceDefaults = UserDefaults(suiteName: glanceSuite) else {
            throw ShotHarness.Failure("could not open the throwaway defaults suite \(glanceSuite)")
        }
        defer { glanceDefaults.removePersistentDomain(forName: glanceSuite) }
        glance = GlancePreferences(defaults: glanceDefaults)
        try ShotHarness.check(glance?.isEnabled == true, "the Session widget switch starts on, from a throwaway defaults suite")

        let env = AppEnvironment.shared
        let updates = env.updates
        updates.version = "0.1.0"
        updates.build = "1"
        let checked = Calendar.current.date(bySettingHour: 9, minute: 14, second: 0, of: Date()) ?? Date()
        let states: [(String, UpdateController.Status)] = [
            ("not-checked", .notChecked),
            ("up-to-date", .upToDate),
            ("checking", .checking),
            ("available", .available(version: "0.2.0")),
            ("failed", .failed),
            ("unavailable", .unavailable("This build has no update source. Install a release build to receive updates.")),
        ]

        for choice in [AppearanceChoice.dark, .light] {
            let shell = ShellModel(tabs: DemoTabs.make(), appearance: AppearanceStore(forced: choice))
            let toasts = ToastCenter(announce: false)
            shell.select("activity")
            shell.openSettings()
            try ShotHarness.check(shell.isSettingsOpen && shell.settingsSection == .appearance, "Settings opens on Appearance")
            try write(shell, toasts, env, "settings-appearance", choice, to: directory)

            shell.appearance.theme = .system
            try write(shell, toasts, env, "settings-appearance-system", choice, to: directory)
            shell.appearance.theme = ThemeSetting(choice)

            try atLarge(shell) { try write(shell, toasts, env, "settings-appearance-large", choice, to: directory) }

            shell.settingsSection = .limits
            try write(shell, toasts, env, "settings-limits", choice, to: directory)

            shell.settingsSection = .update
            for (name, status) in states {
                let running: Bool
                if case .unavailable = status { running = false } else { running = true }
                updates.isRunning = running
                updates.automaticChecks = running
                updates.status = status
                updates.lastCheck = status == .notChecked ? nil : checked
                try write(shell, toasts, env, "settings-update-\(name)", choice, to: directory)
            }

            shell.openPalette()
            try ShotHarness.check(shell.isSettingsOpen && shell.isPaletteOpen, "the palette opens over Settings")
            try write(shell, toasts, env, "settings-palette", choice, to: directory)
            shell.select("agents")
            try ShotHarness.check(!shell.isSettingsOpen && !shell.isPaletteOpen, "choosing a tab closes Settings")

            for tab in ["agents", "activity", "limits"] {
                shell.select(tab)
                try atLarge(shell) { try write(shell, toasts, env, "large-\(tab)", choice, to: directory) }
            }
        }
    }

    /// The Large step for one shot; the shot store is not the app's, so the step is set here and put back.
    private static func atLarge(_ shell: ShellModel, _ shot: () throws -> Void) throws {
        shell.appearance.fontSize = .large
        TypeScale.shared.step = FontSizeChoice.large.step
        defer {
            TypeScale.shared.step = FontSizeChoice.standard.step
            shell.appearance.fontSize = .standard
        }
        try shot()
    }

    /// What the Session widget switch shows in these shots; set at the start of `run`.
    private static var glance: GlancePreferences?

    private static func write(_ shell: ShellModel, _ toasts: ToastCenter, _ env: AppEnvironment, _ name: String,
                              _ choice: AppearanceChoice, to directory: URL) throws {
        let view = AppShell()
            .spaceVibeRoot(shell: shell, toasts: toasts, env: env)
            .environment(\.glancePreferences, glance)
            .frame(width: ShotRenderer.size.width, height: ShotRenderer.size.height)
        try ShotRenderer.write(view, name: name, choice: choice, to: directory)
    }
}
