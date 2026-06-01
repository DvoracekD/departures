import CoreLocation
import Foundation

struct StationSelection: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let stopIds: [String]
    let platformCodes: [String]
    let zoneIds: [String]
    let latitude: Double
    let longitude: Double

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case stopIds
        case platformCodes
        case zoneIds
        case latitude
        case longitude
    }

    nonisolated init(
        id: String,
        name: String,
        stopIds: [String],
        platformCodes: [String],
        zoneIds: [String],
        latitude: Double = 0,
        longitude: Double = 0
    ) {
        self.id = id
        self.name = name
        self.stopIds = stopIds
        self.platformCodes = platformCodes
        self.zoneIds = zoneIds
        self.latitude = latitude
        self.longitude = longitude
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        stopIds = try container.decode([String].self, forKey: .stopIds)
        platformCodes = try container.decode([String].self, forKey: .platformCodes)
        zoneIds = try container.decode([String].self, forKey: .zoneIds)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude) ?? 0
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude) ?? 0
    }

    nonisolated var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    nonisolated var hasCoordinate: Bool {
        latitude != 0 || longitude != 0
    }

    nonisolated var displayDetail: String {
        let platforms = platformCodes.isEmpty ? nil : "Platforms " + platformCodes.prefix(6).joined(separator: ", ")
        let zones = zoneIds.isEmpty ? nil : "Zones " + zoneIds.joined(separator: ", ")

        switch (platforms, zones) {
        case let (platforms?, zones?):
            return "\(platforms) · \(zones)"
        case let (platforms?, nil):
            return platforms
        case let (nil, zones?):
            return zones
        case (nil, nil):
            return "\(stopIds.count) stops"
        }
    }

    nonisolated var searchText: String {
        ([name] + platformCodes + zoneIds).joined(separator: " ").departuresSearchKey
    }
}

typealias Station = StationSelection

struct NearbyStation: Hashable, Identifiable, Sendable {
    let station: Station
    let distanceMeters: CLLocationDistance

    var id: String { station.id }
}

struct WatchDeparture: Hashable, Identifiable, Sendable {
    let id: String
    let routeName: String
    let terminalName: String
    let scheduledDeparture: Date
    let predictedDeparture: Date
    let delaySeconds: Int?
    let platformCode: String?
    let updatedAt: Date
}

struct StationDepartureBoard: Hashable, Identifiable, Sendable {
    let station: NearbyStation
    var departures: [WatchDeparture] = []
    var isRefreshing = false
    var lastUpdatedAt: Date?
    var errorMessage: String?

    var id: String { station.id }
}

struct ConnectionConfiguration: Codable, Hashable, Sendable {
    let origin: StationSelection
    let destination: StationSelection
}

struct DepartureSnapshot: Codable, Hashable, Sendable {
    let originName: String
    let destinationName: String
    let routeShortName: String
    let scheduledDeparture: Date
    let predictedDeparture: Date
    let delaySeconds: Int?
    let platformCode: String?
    let tripId: String
    let destinationStopName: String?
    let updatedAt: Date
}

extension String {
    nonisolated var departuresSearchKey: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: Locale(identifier: "cs_CZ"))
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
    }
}

struct GTFSStopsResponse: Decodable {
    let features: [GTFSStopFeature]
}

struct GTFSStopFeature: Decodable {
    let geometry: GeoJSONPoint?
    let properties: GTFSStopProperties
}

struct GeoJSONPoint: Decodable, Hashable, Sendable {
    let coordinates: [Double]

    nonisolated var coordinate: CLLocationCoordinate2D? {
        guard coordinates.count >= 2 else { return nil }
        return CLLocationCoordinate2D(latitude: coordinates[1], longitude: coordinates[0])
    }
}

struct GTFSStopProperties: Codable, Hashable, Sendable {
    let locationType: Int?
    let parentStation: String?
    let platformCode: String?
    let stopId: String
    let stopName: String
    let zoneId: String?
    let aswId: String?

    enum CodingKeys: String, CodingKey {
        case locationType = "location_type"
        case parentStation = "parent_station"
        case platformCode = "platform_code"
        case stopId = "stop_id"
        case stopName = "stop_name"
        case zoneId = "zone_id"
        case aswId = "asw_id"
    }

    init(
        locationType: Int?,
        parentStation: String?,
        platformCode: String?,
        stopId: String,
        stopName: String,
        zoneId: String?,
        aswId: String?
    ) {
        self.locationType = locationType
        self.parentStation = parentStation
        self.platformCode = platformCode
        self.stopId = stopId
        self.stopName = stopName
        self.zoneId = zoneId
        self.aswId = aswId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        locationType = try container.decodeIfPresent(Int.self, forKey: .locationType)
        parentStation = try container.decodeIfPresent(String.self, forKey: .parentStation)
        platformCode = try container.decodeIfPresent(String.self, forKey: .platformCode)
        stopId = try container.decodeIfPresent(String.self, forKey: .stopId) ?? ""
        stopName = try container.decodeIfPresent(String.self, forKey: .stopName) ?? ""
        zoneId = try container.decodeIfPresent(String.self, forKey: .zoneId)
        aswId = try container.decodeIfPresent(String.self, forKey: .aswId)
    }
}

struct StationStop: Sendable {
    let properties: GTFSStopProperties
    let coordinate: CLLocationCoordinate2D
}

struct PIDDepartureBoardResponse: Decodable {
    let departures: [PIDDeparture]
}

struct PIDDeparture: Decodable, Hashable, Sendable {
    let delay: PIDDepartureDelay
    let departureTimestamp: PIDDepartureStopTime
    let route: PIDDepartureRoute
    let stop: PIDDepartureStopReference
    let trip: PIDDepartureTrip

    enum CodingKeys: String, CodingKey {
        case delay
        case departureTimestamp = "departure_timestamp"
        case route
        case stop
        case trip
    }
}

extension PIDDeparture {
    func makeWatchDeparture(updatedAt: Date) -> WatchDeparture {
        let scheduled = departureTimestamp.scheduled
        let predicted = departureTimestamp.predicted ?? scheduled
        let routeName = route.shortName ?? trip.shortName ?? "?"
        let delaySeconds = delay.isAvailable ? Int((delay.seconds ?? 0).rounded()) : nil

        return WatchDeparture(
            id: "\(trip.id)|\(stop.id)|\(scheduled.timeIntervalSinceReferenceDate)",
            routeName: routeName,
            terminalName: trip.headsign,
            scheduledDeparture: scheduled,
            predictedDeparture: predicted,
            delaySeconds: delaySeconds,
            platformCode: stop.platformCode,
            updatedAt: updatedAt
        )
    }
}

struct PIDDepartureDelay: Decodable, Hashable, Sendable {
    let isAvailable: Bool
    let minutes: Double?
    let seconds: Double?

    enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
        case minutes
        case seconds
    }
}

struct PIDDepartureStopTime: Decodable, Hashable, Sendable {
    let predicted: Date?
    let scheduled: Date
    let minutes: String?
}

struct PIDDepartureRoute: Decodable, Hashable, Sendable {
    let shortName: String?
    let type: Int?

    enum CodingKeys: String, CodingKey {
        case shortName = "short_name"
        case type
    }
}

struct PIDDepartureStopReference: Decodable, Hashable, Sendable {
    let id: String
    let platformCode: String?

    enum CodingKeys: String, CodingKey {
        case id
        case platformCode = "platform_code"
    }
}

struct PIDDepartureTrip: Decodable, Hashable, Sendable {
    let headsign: String
    let id: String
    let isCanceled: Bool?
    let shortName: String?

    enum CodingKeys: String, CodingKey {
        case headsign
        case id
        case isCanceled = "is_canceled"
        case shortName = "short_name"
    }
}

struct GTFSTripDetailResponse: Decodable {
    let tripId: String
    let stopTimes: [GTFSStopTime]?

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case stopTimes = "stop_times"
    }
}

struct GTFSStopTime: Decodable, Hashable, Sendable {
    let arrivalTime: String
    let departureTime: String
    let stopId: String
    let stopSequence: Int

    enum CodingKeys: String, CodingKey {
        case arrivalTime = "arrival_time"
        case departureTime = "departure_time"
        case stopId = "stop_id"
        case stopSequence = "stop_sequence"
    }
}
