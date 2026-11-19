import Foundation
import Observation

/// The glance widget's limit readings (spec `docs/specs/2026-11-19-limit-reset-countdown.md`, LC-R8; GW-R1 widened by GW21):
/// while the widget is on, one `limits.read` every `readInterval`, through the app's one `LimitsModel`, so the widget and the
/// Limits page share a reading and the read needs no tab and no window. The countdown itself needs no read: it counts down
/// from `resetsAt` on the clock (`GlanceCountdown`).
///
/// `stop()` ends the loop, so with the widget's switch off no read runs for it (GW-R10). The model keeps its last reading,
/// which belongs to the Limits page too.
@MainActor
@Observable
final class GlanceLimitsFeed {
    /// How often the widget reads the limits (LC-R8), as often as the Limits page does (`LimitsModel.interval`).
    nonisolated static let readInterval: Duration = .seconds(60)

    let limits: LimitsModel
    private(set) var isRunning = false

    @ObservationIgnored private let interval: Duration
    @ObservationIgnored private var loop: Task<Void, Never>?

    /// `interval` is for tests; the widget reads every `readInterval`.
    init(limits: LimitsModel, interval: Duration = GlanceLimitsFeed.readInterval) {
        self.limits = limits
        self.interval = interval
    }

    /// The readings the widget draws from.
    var results: [CoreLimitsEntry] { limits.results }

    /// Reads now, then every interval until `stop()`. A second call while running does nothing.
    func start() {
        guard loop == nil else { return }
        isRunning = true
        let interval = interval
        // The loop holds the feed weakly, so a feed released without `stop()` ends at its next wake.
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let limits = self?.limits else { return }
                await limits.readOnce()
                try? await Task.sleep(for: interval)
            }
        }
    }

    /// Ends the loop; a read already running finishes, and none follows. A second call does nothing more.
    func stop() {
        loop?.cancel()
        loop = nil
        isRunning = false
    }
}
