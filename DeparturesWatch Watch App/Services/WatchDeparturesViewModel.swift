import CoreLocation
import Foundation
import Observation

@MainActor
@Observable
final class WatchDeparturesViewModel {
    var hasToken = false
    var isBootstrapping = false
    var isLoadingStations = false
    var isLocating = false
    var selectedStationID = ""
    var nearbyStations: [NearbyStation] = []
    var boards: [String: StationDepartureBoard] = [:]
    var errorMessage: String?
    var statusMessage: String?

    @ObservationIgnored private let tokenStore = KeychainTokenStore()
    @ObservationIgnored private let stationCache = StationCacheStore()
    @ObservationIgnored private let locationProvider = LocationProvider()
    @ObservationIgnored private var client: GolemioClient?
    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    @ObservationIgnored private var didBootstrap = false
    @ObservationIgnored private var activeToken: String?
    @ObservationIgnored private var isReloading = false

    private let carouselLimit = 24

    deinit {
        pollingTask?.cancel()
    }

    var selectedStation: NearbyStation? {
        nearbyStations.first { $0.id == selectedStationID } ?? nearbyStations.first
    }

    var selectedBoard: StationDepartureBoard? {
        guard let selectedStation else { return nil }
        return boards[selectedStation.id]
    }

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        isBootstrapping = true
        defer { isBootstrapping = false }

        #if canImport(WatchConnectivity)
        WatchConnectivityService.shared.onTokenReceived = { [weak self] token in
            Task { await self?.applyReceivedToken(token) }
        }
        #endif

        guard let token = currentToken() else {
            hasToken = false
            return
        }

        activeToken = token
        client = GolemioClient(accessToken: token)
        hasToken = true
        await reloadNearbyStations()
    }

    /// Applies a token pushed from the paired iPhone while the watch app is running.
    /// The iPhone sends the token over two channels for reliable delivery, so ignore
    /// a token we have already applied to avoid kicking off duplicate work.
    func applyReceivedToken(_ token: String) async {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != activeToken else { return }

        activeToken = trimmed
        client = GolemioClient(accessToken: trimmed)
        hasToken = true
        errorMessage = nil
        await reloadNearbyStations(forceStationRefresh: true)
    }

    /// Reads the token from the keychain, falling back to any token the iPhone
    /// published before the watch app launched.
    private func currentToken() -> String? {
        if let stored = tokenStore.readToken()?.trimmingCharacters(in: .whitespacesAndNewlines),
           !stored.isEmpty {
            return stored
        }

        #if canImport(WatchConnectivity)
        if let pending = WatchConnectivityService.shared.pendingToken() {
            try? tokenStore.saveToken(pending)
            return pending
        }
        #endif

        return nil
    }

    func reloadNearbyStations(forceStationRefresh: Bool = false) async {
        guard let client else { return }
        guard !isReloading else { return }
        isReloading = true
        defer { isReloading = false }

        isLocating = true
        defer { isLocating = false }

        do {
            let location = try await locationProvider.currentLocation()

            isLoadingStations = true
            let stations = try await stationCache.loadStations(client: client, forceRefresh: forceStationRefresh)
            isLoadingStations = false

            let userLocation = location.coordinate
            let sorted = stations
                .map { station in
                    NearbyStation(
                        station: station,
                        distanceMeters: CLLocation(latitude: station.latitude, longitude: station.longitude)
                            .distance(from: CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude))
                    )
                }
                .sorted { lhs, rhs in
                    lhs.distanceMeters < rhs.distanceMeters
                }

            nearbyStations = Array(sorted.prefix(carouselLimit))
            selectedStationID = nearbyStations.first?.id ?? ""
            boards = Dictionary(uniqueKeysWithValues: nearbyStations.map { station in
                (station.id, boards[station.id] ?? StationDepartureBoard(station: station))
            })

            await refreshSelectedDepartures()
            startPolling()
        } catch {
            isLoadingStations = false
            errorMessage = error.localizedDescription
        }
    }

    func selectedStationDidChange() {
        guard !selectedStationID.isEmpty else { return }

        Task {
            await refreshSelectedDepartures()
            startPolling()
        }
    }

    func refreshSelectedDepartures(showErrorsAsAlert: Bool = false) async {
        guard let selectedStation else { return }
        await refreshDepartures(for: selectedStation, showErrorsAsAlert: showErrorsAsAlert)
    }

    func refreshDepartures(for station: NearbyStation, showErrorsAsAlert: Bool = false) async {
        guard let client else { return }

        setBoardRefreshing(true, for: station)
        defer { setBoardRefreshing(false, for: station) }

        do {
            let updatedAt = Date()
            let departures = try await client.fetchDepartures(stopIds: station.station.stopIds, limit: 3)
                .filter { $0.trip.isCanceled != true }
                .map { $0.makeWatchDeparture(updatedAt: updatedAt) }
                .sorted { lhs, rhs in
                    lhs.predictedDeparture < rhs.predictedDeparture
                }

            var board = boards[station.id] ?? StationDepartureBoard(station: station)
            board.departures = Array(departures.prefix(3))
            board.lastUpdatedAt = updatedAt
            board.errorMessage = nil
            boards[station.id] = board
            statusMessage = "Updated \(DepartureFormatting.updatedTime.string(from: updatedAt))."
        } catch {
            var board = boards[station.id] ?? StationDepartureBoard(station: station)
            board.errorMessage = error.localizedDescription
            boards[station.id] = board

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
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10 * 1_000_000_000)
                await self?.refreshSelectedDepartures()
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func setBoardRefreshing(_ isRefreshing: Bool, for station: NearbyStation) {
        var board = boards[station.id] ?? StationDepartureBoard(station: station)
        board.isRefreshing = isRefreshing
        boards[station.id] = board
    }
}
