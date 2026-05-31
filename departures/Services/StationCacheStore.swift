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

    func loadStations(client: GolemioClient, forceRefresh: Bool = false) async throws -> [StationSelection] {
        if !forceRefresh, let cached = try? loadFreshStations() {
            return cached
        }

        let stops = try await client.fetchAllStops()
        let stations = StationIndexBuilder.makeStations(from: stops)
        try save(stations)
        return stations
    }

    func loadFreshStations() throws -> [StationSelection]? {
        let envelope = try loadEnvelope()
        let age = Date().timeIntervalSince(envelope.refreshedAt)
        return age <= maxAge ? envelope.stations : nil
    }

    func clear() throws {
        guard fileManager.fileExists(atPath: cacheURL.path) else { return }
        try fileManager.removeItem(at: cacheURL)
    }

    private func loadEnvelope() throws -> StationCacheEnvelope {
        let data = try Data(contentsOf: cacheURL)
        return try JSONDecoder().decode(StationCacheEnvelope.self, from: data)
    }

    private func save(_ stations: [StationSelection]) throws {
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
    let stations: [StationSelection]
    let refreshedAt: Date
}

enum StationIndexBuilder {
    nonisolated static func makeStations(from stops: [GTFSStopProperties]) -> [StationSelection] {
        let uniqueStops = Dictionary(grouping: stops.filter { stop in
            (stop.locationType ?? 0) == 0 && !stop.stopId.isEmpty && !stop.stopName.isEmpty
        }, by: \.stopId)
        .compactMap { _, groupedStops in groupedStops.first }

        let groupedStops = Dictionary(grouping: uniqueStops, by: stationGroupKey(for:))

        return groupedStops.values.compactMap { stops in
            makeStation(from: stops)
        }
        .sorted { lhs, rhs in
            lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    nonisolated private static func stationGroupKey(for stop: GTFSStopProperties) -> String {
        if let parentStation = stop.parentStation?.nilIfBlank {
            return "parent:\(parentStation)"
        }

        let zone = stop.zoneId?.nilIfBlank ?? ""
        return "name:\(stop.stopName.departuresSearchKey)|zone:\(zone)"
    }

    nonisolated private static func makeStation(from stops: [GTFSStopProperties]) -> StationSelection? {
        let stopIds = stops.map(\.stopId).uniqueSorted()
        guard !stopIds.isEmpty else { return nil }

        let parentStation = stops.compactMap { $0.parentStation?.nilIfBlank }.first
        let id = parentStation ?? "stops:" + stopIds.joined(separator: "|")
        let name = mostFrequent(stops.map(\.stopName)) ?? stops[0].stopName
        let platformCodes = stops.compactMap { $0.platformCode?.nilIfBlank }.uniqueSorted()
        let zoneIds = stops.flatMap { stop in
            (stop.zoneId ?? "")
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        .filter { !$0.isEmpty }
        .uniqueSorted()

        return StationSelection(
            id: id,
            name: name,
            stopIds: stopIds,
            platformCodes: platformCodes,
            zoneIds: zoneIds
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
}
