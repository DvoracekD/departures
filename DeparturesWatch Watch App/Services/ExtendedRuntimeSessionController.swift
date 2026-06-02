import Observation
import WatchKit

/// Keeps the connection-detail screen frontmost while the wrist is lowered and the
/// display enters always-on, the way the Workouts app behaves. This is the sanctioned
/// non-HealthKit mechanism: a `WKExtendedRuntimeSession` of type `.physicalTherapy`.
///
/// The session is single-use — once invalidated it cannot be restarted, so `start()`
/// always creates a fresh instance. There is no veto for expiration; `willExpire` is
/// purely informational.
@MainActor
@Observable
final class ExtendedRuntimeSessionController: NSObject, WKExtendedRuntimeSessionDelegate {
    private(set) var isRunning = false

    @ObservationIgnored private var session: WKExtendedRuntimeSession?

    func start() {
        guard session?.state != .running else { return }

        let session = WKExtendedRuntimeSession()
        session.delegate = self
        session.start()
        self.session = session
    }

    func stop() {
        session?.invalidate()
        session = nil
        isRunning = false
    }

    // MARK: - WKExtendedRuntimeSessionDelegate
    // WatchKit delivers these callbacks on the main thread.

    nonisolated func extendedRuntimeSessionDidStart(_ session: WKExtendedRuntimeSession) {
        MainActor.assumeIsolated { self.isRunning = true }
    }

    nonisolated func extendedRuntimeSessionWillExpire(_ session: WKExtendedRuntimeSession) {
        // Informational only — the session cannot be reprieved.
    }

    nonisolated func extendedRuntimeSession(
        _ session: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {
        MainActor.assumeIsolated {
            self.isRunning = false
            self.session = nil
        }
    }
}
