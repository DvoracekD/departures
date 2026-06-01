import Foundation

#if canImport(WatchConnectivity)
import WatchConnectivity

final class WatchConnectivityService: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityService()

    #if os(watchOS)
    /// Invoked on the main actor whenever a fresh token arrives from the paired iPhone.
    var onTokenReceived: ((String) -> Void)?
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
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let context = [PayloadKey.token: token]
        try? session.updateApplicationContext(context)

        if session.isPaired, session.isWatchAppInstalled {
            session.transferUserInfo(context)
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

    private nonisolated func receiveToken(from payload: [String: Any]) {
        guard let token = payload[PayloadKey.token] as? String else { return }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task { @MainActor in self.store(trimmed) }
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
        receiveToken(from: applicationContext)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        receiveToken(from: userInfo)
    }
    #endif
}

private enum PayloadKey {
    static let token = "token"
}
#endif
