import Foundation

struct StationSelection: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let stopIds: [String]
    let platformCodes: [String]
    let zoneIds: [String]

    var displayDetail: String {
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

    var searchText: String {
        ([name] + platformCodes + zoneIds).joined(separator: " ").departuresSearchKey
    }
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
    let properties: GTFSStopProperties
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
