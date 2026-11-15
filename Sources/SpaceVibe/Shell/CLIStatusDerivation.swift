import Foundation

/// What the sidebar's CLI status rows say, derived from the one CLI-level reading the shell holds: `limits.read`, which looks
/// at each CLI's folder and files (G9). The shell holds no direct "log is being read" flag, so:
///
/// - `notInstalled` (the CLI's folder is missing) is `not installed`;
/// - `notMeasurable` (Gemini CLI keeps no limit on disk, and the app reads no Gemini log) is `no log`;
/// - `measured` (the app holds a reading) is `reading`;
/// - `notRecorded` (the folder is there but holds no reading yet) is `no data` (the Limits page's "no reading", shortened to fit the row);
/// - `unreadable` (a record the app cannot parse) and a CLI not read yet have no state in the mock, so they show none.
///
/// "reading" is therefore "the app holds a usage reading for this CLI", not a live check that a log is open.
enum CLIStatusDerivation {
    static func state(of entry: CoreLimitsEntry?) -> SidebarCLIState? {
        guard let entry else { return nil }
        switch entry.state {
        case .measured: return .reading
        case .notRecorded: return .noReading
        case .notInstalled: return .notInstalled
        case .notMeasurable: return .noLog
        case .unreadable: return nil
        }
    }
}
