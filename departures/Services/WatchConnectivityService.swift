import Foundation

#if canImport(WatchConnectivity)
import WatchConnectivity

final class WatchConnectivityService: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityService()

    private override init() {
        super.init()
        activate()
    }

    func update(connection: ConnectionConfiguration, snapshot: DepartureSnapshot?) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        var context: [String: Any] = [:]
        let encoder = JSONEncoder()

        if let connectionData = try? encoder.encode(connection) {
            context[PayloadKey.connection] = connectionData
        }

        if let snapshot, let snapshotData = try? encoder.encode(snapshot) {
            context[PayloadKey.snapshot] = snapshotData
        }

        guard !context.isEmpty else { return }
        try? session.updateApplicationContext(context)

        #if os(iOS)
        if session.isPaired, session.isWatchAppInstalled {
            session.transferUserInfo(context)
        }
        #endif
    }

    private func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}

enum WatchConnectivityPayloadDecoder {
    static func connection(from userInfo: [String: Any]) -> ConnectionConfiguration? {
        guard let data = userInfo[PayloadKey.connection] as? Data else { return nil }
        return try? JSONDecoder().decode(ConnectionConfiguration.self, from: data)
    }

    static func snapshot(from userInfo: [String: Any]) -> DepartureSnapshot? {
        guard let data = userInfo[PayloadKey.snapshot] as? Data else { return nil }
        return try? JSONDecoder().decode(DepartureSnapshot.self, from: data)
    }
}

private enum PayloadKey {
    static let connection = "connection"
    static let snapshot = "snapshot"
}
#endif
