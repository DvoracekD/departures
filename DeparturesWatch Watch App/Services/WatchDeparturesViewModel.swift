import CoreLocation
import Foundation
import Observation

@MainActor
@Observable
final class WatchDeparturesViewModel {
    var tokenDraft = ""
    var hasToken = false
    var isBootstrapping = false
    var isSavingToken = false
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

        tokenDraft = tokenStore.readToken() ?? ""
        hasToken = !tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        configureClientIfPossible()

        guard hasToken else { return }
        await reloadNearbyStations()
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
            hasToken = true
            statusMessage = nil
            await reloadNearbyStations(forceStationRefresh: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reloadNearbyStations(forceStationRefresh: Bool = false) async {
        guard let client else { return }

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

    func forgetToken() {
        stopPolling()
        try? tokenStore.deleteToken()
        tokenDraft = ""
        hasToken = false
        client = nil
        nearbyStations = []
        boards = [:]
        selectedStationID = ""
        statusMessage = nil
    }

    private func configureClientIfPossible() {
        let token = tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }
        client = GolemioClient(accessToken: token)
    }

    private func setBoardRefreshing(_ isRefreshing: Bool, for station: NearbyStation) {
        var board = boards[station.id] ?? StationDepartureBoard(station: station)
        board.isRefreshing = isRefreshing
        boards[station.id] = board
    }
}
