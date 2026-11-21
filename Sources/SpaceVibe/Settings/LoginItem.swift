import Foundation
import Observation
import ServiceManagement

/// What macOS says about SpaceVibe as a login item (`SMAppService.Status`), in the app's terms.
enum LoginItemStatus: Equatable, Sendable {
    /// Not registered: SpaceVibe does not open at login.
    case off
    /// Registered and allowed.
    case on
    /// Registered, but the user has not allowed it in System Settings › General › Login Items yet.
    case needsApproval
    /// This copy cannot be a login item (macOS does not find it, a test launch); the reason is shown as is.
    case unavailable(String)

    /// The switch reads on once SpaceVibe asked, approved or not: turning it off unregisters either way.
    var isOn: Bool { self == .on || self == .needsApproval }
    var canChange: Bool { if case .unavailable = self { false } else { true } }
}

/// The seam over `SMAppService.mainApp`, so tests and screenshots never register the running process.
@MainActor
protocol LoginItemService: AnyObject {
    var status: LoginItemStatus { get }
    func register() throws
    func unregister() throws
    func openSystemSettings()
}

/// The real login item: SpaceVibe itself (`SMAppService.mainApp`). Never registered on its own (off by default, RB-R8); only
/// the Settings switch calls `register`, and macOS then asks the user to allow it in System Settings.
@MainActor
final class MainAppLoginItem: LoginItemService {
    var status: LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .notRegistered: .off
        case .enabled: .on
        case .requiresApproval: .needsApproval
        case .notFound: .unavailable(LoginItemWording.notFound)
        @unknown default: .unavailable(LoginItemWording.notFound)
        }
    }

    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
    func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}

/// A login item that never reaches macOS: a test launch (unavailable, with why) or a screenshot (any status). `failure`
/// makes the next change throw, for the refused-setting state.
@MainActor
final class StandInLoginItem: LoginItemService {
    struct Refused: LocalizedError {
        let errorDescription: String?
    }

    var status: LoginItemStatus
    var failure: String?

    init(status: LoginItemStatus, failure: String? = nil) {
        self.status = status
        self.failure = failure
    }

    func register() throws {
        if let failure { throw Refused(errorDescription: failure) }
        status = .needsApproval
    }

    func unregister() throws {
        if let failure { throw Refused(errorDescription: failure) }
        status = .off
    }

    func openSystemSettings() {}
}

/// Settings › General › Open at login (RB-R8, "Inferred, not decided": Open at login). It reads the status from macOS each
/// time it is asked (`refresh`, on the window's appearance), so a choice made in System Settings shows here, and it reports
/// that status as it is: on, waiting for approval, off or unavailable. A refusal from macOS changes nothing and comes back as
/// the sentence for the error toast.
@MainActor
@Observable
final class LoginItem {
    static let shared = LoginItem(service: CLIPreferences.isTestLaunch()
        ? StandInLoginItem(status: .unavailable(LoginItemWording.testLaunch)) : MainAppLoginItem())

    private(set) var status: LoginItemStatus
    @ObservationIgnored private let service: any LoginItemService

    init(service: any LoginItemService) {
        self.service = service
        status = service.status
    }

    func refresh() { status = service.status }

    /// Registers or unregisters; nil when macOS accepted, else the toast's sentence. The status is read again either way.
    func set(_ isOn: Bool) -> String? {
        defer { refresh() }
        guard status.canChange, isOn != status.isOn else { return nil }
        do {
            if isOn { try service.register() } else { try service.unregister() }
            return nil
        } catch {
            return LoginItemWording.refused(turningOn: isOn, reason: (error as? LocalizedError)?.errorDescription)
        }
    }

    func openSystemSettings() { service.openSystemSettings() }
}

enum LoginItemWording {
    static let title = "Open at login"
    static let detail = "Start SpaceVibe when you sign in to this Mac. macOS asks you to allow it in System Settings › Login Items."
    static let needsApproval = "Needs approval in System Settings › Login Items."
    static let openSettings = "Open Login Items"
    static let notFound = "macOS cannot find this copy of SpaceVibe. Move it to the Applications folder, then try again."
    static let testLaunch = "Not available in a test launch."

    /// "Couldn’t turn on Open at login: <reason>. Nothing changed."
    static func refused(turningOn: Bool, reason: String?) -> String {
        let head = "Couldn\u{2019}t turn \(turningOn ? "on" : "off") Open at login"
        guard let reason, !reason.isEmpty else { return head + ". Nothing changed." }
        let trimmed = reason.hasSuffix(".") ? String(reason.dropLast()) : reason
        return head + ": " + trimmed + ". Nothing changed."
    }
}
