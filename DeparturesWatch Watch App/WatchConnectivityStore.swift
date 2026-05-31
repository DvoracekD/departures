import Foundation
import Observation
import WatchConnectivity

/// Receives the connection + departure snapshot pushed from the iOS app over
/// WatchConnectivity and publishes them to the watch UI.
@MainActor
@Observable
final class WatchConnectivityStore: NSObject, WCSessionDelegate {
    var snapshot: DepartureSnapshot?
    var connection: ConnectionConfiguration?
    var isReachable = false

    override init() {
        super.init()
        activate()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    private func ingest(_ payload: [String: Any]) {
        if let snapshot = WatchConnectivityPayloadDecoder.snapshot(from: payload) {
            self.snapshot = snapshot
        }
        if let connection = WatchConnectivityPayloadDecoder.connection(from: payload) {
            self.connection = connection
        }
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // Pull whatever the phone last sent so the UI is populated immediately
        // after launch, before any new context arrives.
        let context = session.receivedApplicationContext
        let reachable = session.isReachable
        Task { @MainActor in
            self.isReachable = reachable
            self.ingest(context)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in self.ingest(applicationContext) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in self.ingest(userInfo) }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.isReachable = reachable }
    }
}
