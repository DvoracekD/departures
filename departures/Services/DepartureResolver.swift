import Foundation

final class DepartureResolver {
    private let client: GolemioClient
    private var tripStopTimesCache: [String: [GTFSStopTime]] = [:]

    init(client: GolemioClient) {
        self.client = client
    }

    func closestDirectConnection(for configuration: ConnectionConfiguration) async throws -> DepartureSnapshot? {
        let departures = try await client.fetchDepartures(originStopIds: configuration.origin.stopIds)
        let orderedDepartures = departures
            .filter { $0.trip.isCanceled != true }
            .sorted { lhs, rhs in
                let lhsDate = lhs.departureTimestamp.predicted ?? lhs.departureTimestamp.scheduled
                let rhsDate = rhs.departureTimestamp.predicted ?? rhs.departureTimestamp.scheduled
                return lhsDate < rhsDate
            }

        let originStopIds = Set(configuration.origin.stopIds)
        let destinationStopIds = Set(configuration.destination.stopIds)

        for departure in orderedDepartures {
            let serviceDate = departure.departureTimestamp.scheduled
            let stopTimes = try await stopTimes(for: departure.trip.id, serviceDate: serviceDate)
            guard let originSequence = originSequence(
                for: departure,
                stopTimes: stopTimes,
                fallbackOriginStopIds: originStopIds
            ) else {
                continue
            }

            guard let destinationStopTime = stopTimes
                .filter({ destinationStopIds.contains($0.stopId) && $0.stopSequence > originSequence })
                .min(by: { $0.stopSequence < $1.stopSequence }) else {
                continue
            }

            let scheduled = departure.departureTimestamp.scheduled
            let predicted = departure.departureTimestamp.predicted ?? scheduled
            let delaySeconds = departure.delay.isAvailable ? Int(departure.delay.seconds ?? 0) : nil

            return DepartureSnapshot(
                originName: configuration.origin.name,
                destinationName: configuration.destination.name,
                routeShortName: departure.route.shortName ?? departure.trip.shortName ?? "?",
                scheduledDeparture: scheduled,
                predictedDeparture: predicted,
                delaySeconds: delaySeconds,
                platformCode: departure.stop.platformCode,
                tripId: departure.trip.id,
                destinationStopName: destinationStopTime.stopId,
                updatedAt: Date()
            )
        }

        return nil
    }

    func clearCache() {
        tripStopTimesCache.removeAll()
    }

    private func originSequence(
        for departure: PIDDeparture,
        stopTimes: [GTFSStopTime],
        fallbackOriginStopIds: Set<String>
    ) -> Int? {
        if let exactStopTime = stopTimes.first(where: { $0.stopId == departure.stop.id }) {
            return exactStopTime.stopSequence
        }

        return stopTimes
            .filter { fallbackOriginStopIds.contains($0.stopId) }
            .min(by: { $0.stopSequence < $1.stopSequence })?
            .stopSequence
    }

    private func stopTimes(for tripId: String, serviceDate: Date) async throws -> [GTFSStopTime] {
        let dateString = GolemioDateFormatters.serviceDate.string(from: serviceDate)
        let cacheKey = "\(tripId)|\(dateString)"

        if let cached = tripStopTimesCache[cacheKey] {
            return cached
        }

        let stopTimes = try await client.fetchTripStopTimes(tripId: tripId, serviceDate: serviceDate)
        tripStopTimesCache[cacheKey] = stopTimes
        return stopTimes
    }
}
