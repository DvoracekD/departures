import Foundation

#if canImport(WatchConnectivity)
import WatchConnectivity

final class WatchConnectivityService: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityService()

    #if os(watchOS)
    /// Invoked on the main actor whenever a fresh token arrives from the paired iPhone.
    var onTokenReceived: ((String) -> Void)?
    /// Invoked on the main actor whenever fresh nearby-station preferences arrive.
    var onPreferencesReceived: ((NearbyStationsPreferences) -> Void)?
    private let tokenStore = KeychainTokenStore()
    #endif

    private override init() {
        super.init()
        activate()
    }

    private func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    #if os(iOS)
    func send(token: String) {
        publish([PayloadKey.token: token])
    }

    func send(preferences: NearbyStationsPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        publish([PayloadKey.preferences: data])
    }

    /// Merges `values` into the watch's application context (so the latest token
    /// and preferences both survive), and also delivers them while the watch app
    /// is running.
    private func publish(_ values: [String: Any]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        var context = session.applicationContext
        context.merge(values) { _, new in new }
        try? session.updateApplicationContext(context)

        if session.isPaired, session.isWatchAppInstalled {
            session.transferUserInfo(values)
        }
    }
    #endif

    #if os(watchOS)
    /// The most recent token the iPhone published while the watch app was not running.
    func pendingToken() -> String? {
        guard WCSession.isSupported() else { return nil }
        let token = WCSession.default.receivedApplicationContext[PayloadKey.token] as? String
        let trimmed = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false) ? trimmed : nil
    }

    /// The most recent preferences the iPhone published while the watch app was not running.
    func pendingPreferences() -> NearbyStationsPreferences? {
        guard WCSession.isSupported() else { return nil }
        guard let data = WCSession.default.receivedApplicationContext[PayloadKey.preferences] as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(NearbyStationsPreferences.self, from: data)
    }

    private nonisolated func receive(from payload: [String: Any]) {
        if let token = payload[PayloadKey.token] as? String {
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                Task { @MainActor in self.store(trimmed) }
            }
        }

        if let data = payload[PayloadKey.preferences] as? Data,
           let preferences = try? JSONDecoder().decode(NearbyStationsPreferences.self, from: data) {
            Task { @MainActor in self.onPreferencesReceived?(preferences) }
        }
    }

    @MainActor
    private func store(_ token: String) {
        try? tokenStore.saveToken(token)
        onTokenReceived?(token)
    }
    #endif

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

    #if os(watchOS)
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        receive(from: applicationContext)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        receive(from: userInfo)
    }
    #endif
}

private enum PayloadKey {
    static let token = "token"
    static let preferences = "preferences"
}
#endif
