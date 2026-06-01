import CoreLocation
import Foundation

final class StationCacheStore {
    private let fileManager: FileManager
    private let cacheURL: URL
    private let maxAge: TimeInterval = 24 * 60 * 60

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let appDirectory = supportDirectory.appendingPathComponent("departures", isDirectory: true)
        self.cacheURL = appDirectory.appendingPathComponent("station-cache.json")
    }

    func loadStations(client: GolemioClient, forceRefresh: Bool = false) async throws -> [Station] {
        if !forceRefresh, let cached = try? loadFreshStations() {
            return cached
        }

        let stops = try await client.fetchAllStopFeatures()
        let stations = StationIndexBuilder.makeStations(from: stops)
        try save(stations)
        return stations
    }

    func loadFreshStations() throws -> [Station]? {
        let envelope = try loadEnvelope()
        let age = Date().timeIntervalSince(envelope.refreshedAt)
        let hasCoordinates = envelope.stations.allSatisfy(\.hasCoordinate)
        return age <= maxAge && hasCoordinates ? envelope.stations : nil
    }

    func clear() throws {
        guard fileManager.fileExists(atPath: cacheURL.path) else { return }
        try fileManager.removeItem(at: cacheURL)
    }

    private func loadEnvelope() throws -> StationCacheEnvelope {
        let data = try Data(contentsOf: cacheURL)
        return try JSONDecoder().decode(StationCacheEnvelope.self, from: data)
    }

    private func save(_ stations: [Station]) throws {
        let directory = cacheURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let envelope = StationCacheEnvelope(stations: stations, refreshedAt: Date())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(envelope)
        try data.write(to: cacheURL, options: [.atomic])
    }
}

private struct StationCacheEnvelope: Codable {
    let stations: [Station]
    let refreshedAt: Date
}

enum StationIndexBuilder {
    nonisolated static func makeStations(from features: [GTFSStopFeature]) -> [Station] {
        let stops = features.compactMap { feature -> StationStop? in
            let properties = feature.properties
            guard (properties.locationType ?? 0) == 0,
                  !properties.stopId.isEmpty,
                  !properties.stopName.isEmpty,
                  let coordinate = feature.geometry?.coordinate else {
                return nil
            }

            return StationStop(properties: properties, coordinate: coordinate)
        }

        let uniqueStops = Dictionary(grouping: stops, by: \.properties.stopId)
            .compactMap { _, groupedStops in groupedStops.first }
        let groupedStops = Dictionary(grouping: uniqueStops, by: stationGroupKey(for:))

        return groupedStops.values.compactMap { stops in
            makeStation(from: stops)
        }
        .sorted { lhs, rhs in
            lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    nonisolated private static func stationGroupKey(for stop: StationStop) -> String {
        if let aswId = stop.properties.aswId?.nodeId.nilIfBlank {
            return "asw:\(aswId)"
        }

        if let parentStation = stop.properties.parentStation?.nilIfBlank {
            return "parent:\(parentStation)"
        }

        let zone = stop.properties.zoneId?.nilIfBlank ?? ""
        return "name:\(stop.properties.stopName.departuresSearchKey)|zone:\(zone)"
    }

    nonisolated private static func makeStation(from stops: [StationStop]) -> Station? {
        let stopIds = stops.map(\.properties.stopId).uniqueSorted()
        guard !stopIds.isEmpty else { return nil }

        let first = stops[0]
        let aswNode = first.properties.aswId?.nodeId.nilIfBlank
        let parentStation = stops.compactMap { $0.properties.parentStation?.nilIfBlank }.first
        let id = aswNode.map { "asw:\($0)" } ?? parentStation ?? "stops:" + stopIds.joined(separator: "|")
        let name = mostFrequent(stops.map(\.properties.stopName)) ?? first.properties.stopName
        let platformCodes = stops.compactMap { $0.properties.platformCode?.nilIfBlank }.uniqueSorted()
        let zoneIds = stops.flatMap { stop in
            (stop.properties.zoneId ?? "")
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        .filter { !$0.isEmpty }
        .uniqueSorted()

        let latitude = stops.map(\.coordinate.latitude).reduce(0, +) / Double(stops.count)
        let longitude = stops.map(\.coordinate.longitude).reduce(0, +) / Double(stops.count)

        return Station(
            id: id,
            name: name,
            stopIds: stopIds,
            platformCodes: platformCodes,
            zoneIds: zoneIds,
            latitude: latitude,
            longitude: longitude
        )
    }

    nonisolated private static func mostFrequent(_ values: [String]) -> String? {
        Dictionary(grouping: values, by: { $0 })
            .max { lhs, rhs in lhs.value.count < rhs.value.count }?
            .key
    }
}

private extension Sequence where Element == String {
    nonisolated func uniqueSorted() -> [String] {
        Array(Set(self)).sorted { lhs, rhs in
            lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
    }
}

private extension String {
    nonisolated var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    nonisolated var nodeId: String {
        split(separator: "/").first.map(String.init) ?? self
    }
}
