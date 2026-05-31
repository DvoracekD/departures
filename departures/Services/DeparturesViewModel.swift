import Foundation
import Observation

@MainActor
@Observable
final class DeparturesViewModel {
    var tokenDraft = ""
    var hasToken = false
    var isBootstrapping = false
    var isSavingToken = false
    var isLoadingStations = false
    var isSavingConnection = false
    var isRefreshing = false
    var stations: [StationSelection] = []
    var originSearchText = ""
    var destinationSearchText = ""
    var selectedOrigin: StationSelection?
    var selectedDestination: StationSelection?
    var connection: ConnectionConfiguration?
    var snapshot: DepartureSnapshot?
    var errorMessage: String?
    var statusMessage: String?

    @ObservationIgnored private let tokenStore = KeychainTokenStore()
    @ObservationIgnored private let configurationStore = ConfigurationStore()
    @ObservationIgnored private let stationCache = StationCacheStore()
    @ObservationIgnored private var client: GolemioClient?
    @ObservationIgnored private var resolver: DepartureResolver?
    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    @ObservationIgnored private var didBootstrap = false

    deinit {
        pollingTask?.cancel()
    }

    var canSaveConnection: Bool {
        selectedOrigin != nil && selectedDestination != nil && selectedOrigin != selectedDestination && !isSavingConnection
    }

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        isBootstrapping = true
        defer { isBootstrapping = false }

        tokenDraft = tokenStore.readToken() ?? ""
        hasToken = !tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        configureClientIfPossible()

        connection = configurationStore.loadConnection()
        snapshot = configurationStore.loadSnapshot()

        if hasToken, connection == nil {
            await loadStationsIfNeeded()
        }

        if connection != nil {
            startPolling()
        }
    }

    func saveToken() async {
        let token = tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            errorMessage = "Enter a Golemio API token."
            return
        }

        isSavingToken = true
        defer { isSavingToken = false }

        do {
            let newClient = GolemioClient(accessToken: token)
            try await newClient.validateToken()
            try tokenStore.saveToken(token)

            client = newClient
            resolver = DepartureResolver(client: newClient)
            hasToken = true
            statusMessage = nil
            await loadStationsIfNeeded(forceRefresh: stations.isEmpty)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadStationsIfNeeded(forceRefresh: Bool = false) async {
        guard let client else { return }
        if !forceRefresh, !stations.isEmpty { return }

        isLoadingStations = true
        defer { isLoadingStations = false }

        do {
            stations = try await stationCache.loadStations(client: client, forceRefresh: forceRefresh)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func filteredStations(for searchText: String) -> [StationSelection] {
        let query = searchText.departuresSearchKey
        let matches: [StationSelection]

        if query.isEmpty {
            matches = Array(stations.prefix(40))
        } else {
            matches = stations.filter { station in
                station.searchText.contains(query)
            }
        }

        return Array(matches.prefix(40))
    }

    func selectOrigin(_ station: StationSelection) {
        selectedOrigin = station
        originSearchText = station.name
    }

    func selectDestination(_ station: StationSelection) {
        selectedDestination = station
        destinationSearchText = station.name
    }

    func saveConnection() async {
        guard let selectedOrigin, let selectedDestination else { return }
        guard selectedOrigin != selectedDestination else {
            errorMessage = "Choose two different stations."
            return
        }

        let configuration = ConnectionConfiguration(origin: selectedOrigin, destination: selectedDestination)
        isSavingConnection = true
        defer { isSavingConnection = false }

        do {
            try configurationStore.saveConnection(configuration)
            connection = configuration
            statusMessage = "Connection saved."

            if let next = try await resolver?.closestDirectConnection(for: configuration) {
                snapshot = next
                try? configurationStore.saveSnapshot(next)
                statusMessage = "Updated \(DepartureFormatting.updatedTime.string(from: next.updatedAt))."
                syncToWatch()
            } else {
                statusMessage = "No upcoming direct connection found."
                syncToWatch()
            }

            startPolling()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshDeparture(showErrorsAsAlert: Bool = false) async {
        guard let connection, let resolver else { return }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            if let next = try await resolver.closestDirectConnection(for: connection) {
                snapshot = next
                try? configurationStore.saveSnapshot(next)
                statusMessage = "Updated \(DepartureFormatting.updatedTime.string(from: next.updatedAt))."
                syncToWatch()
            } else {
                statusMessage = "No upcoming direct connection found."
                syncToWatch()
            }
        } catch {
            if showErrorsAsAlert {
                errorMessage = error.localizedDescription
            } else {
                statusMessage = error.localizedDescription
            }
        }
    }

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            await self?.refreshDeparture()

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                await self?.refreshDeparture()
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func editConnection() {
        stopPolling()
        if let connection {
            selectedOrigin = connection.origin
            selectedDestination = connection.destination
            originSearchText = connection.origin.name
            destinationSearchText = connection.destination.name
        }
        connection = nil
        Task { await loadStationsIfNeeded() }
    }

    func clearConnection() {
        stopPolling()
        configurationStore.clearConnection()
        configurationStore.clearSnapshot()
        connection = nil
        snapshot = nil
        selectedOrigin = nil
        selectedDestination = nil
        originSearchText = ""
        destinationSearchText = ""
        statusMessage = nil
    }

    func forgetToken() {
        stopPolling()
        try? tokenStore.deleteToken()
        configurationStore.clearConnection()
        configurationStore.clearSnapshot()
        client = nil
        resolver = nil
        hasToken = false
        tokenDraft = ""
        connection = nil
        snapshot = nil
        stations = []
        selectedOrigin = nil
        selectedDestination = nil
        originSearchText = ""
        destinationSearchText = ""
        statusMessage = nil
    }

    private func configureClientIfPossible() {
        let token = tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }
        let golemioClient = GolemioClient(accessToken: token)
        client = golemioClient
        resolver = DepartureResolver(client: golemioClient)
    }

    private func syncToWatch() {
        #if canImport(WatchConnectivity) && os(iOS)
        guard let connection else { return }
        WatchConnectivityService.shared.update(connection: connection, snapshot: snapshot)
        #endif
    }
}
