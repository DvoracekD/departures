import Foundation

struct GolemioClient: Sendable {
    private let baseURL = URL(string: "https://api.golemio.cz")!
    private let accessToken: String

    init(accessToken: String) {
        self.accessToken = accessToken
    }

    func validateToken() async throws {
        _ = try await fetchStopFeaturesPage(limit: 1, offset: 0)
    }

    func fetchAllStopFeatures() async throws -> [GTFSStopFeature] {
        let pageLimit = 10_000
        var offset = 0
        var stops: [GTFSStopFeature] = []

        while true {
            let page = try await fetchStopFeaturesPage(limit: pageLimit, offset: offset)
            stops.append(contentsOf: page)

            if page.count < pageLimit {
                break
            }

            offset += pageLimit
        }

        return stops
    }

    func fetchDepartures(stopIds originStopIds: [String], limit: Int = 3, minutesAfter: Int = 90) async throws -> [PIDDeparture] {
        let stopIds = Array(originStopIds.prefix(100))
        guard !stopIds.isEmpty else {
            throw GolemioClientError.invalidRequest("Station does not contain any GTFS stop IDs.")
        }

        var queryItems = stopIds.map { URLQueryItem(name: "ids[]", value: $0) }
        queryItems.append(contentsOf: [
            URLQueryItem(name: "minutesBefore", value: "0"),
            URLQueryItem(name: "minutesAfter", value: String(minutesAfter)),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "order", value: "real"),
            URLQueryItem(name: "mode", value: "departures"),
            URLQueryItem(name: "skip[]", value: "canceled")
        ])

        let response: PIDDepartureBoardResponse = try await get(path: "/v2/pid/departureboards", queryItems: queryItems)
        return response.departures
    }

    private func fetchStopFeaturesPage(limit: Int, offset: Int) async throws -> [GTFSStopFeature] {
        let response: GTFSStopsResponse = try await get(
            path: "/v2/gtfs/stops",
            queryItems: [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset))
            ]
        )
        return response.features
    }

    private func get<T: Decodable>(path: String, queryItems: [URLQueryItem]) async throws -> T {
        let url = try makeURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(accessToken, forHTTPHeaderField: "X-Access-Token")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GolemioClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            throw GolemioClientError.httpStatus(httpResponse.statusCode, body)
        }

        do {
            return try GolemioDateFormatters.decoder.decode(T.self, from: data)
        } catch {
            throw GolemioClientError.decoding(error)
        }
    }

    private func makeURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = path
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw GolemioClientError.invalidURL
        }

        return url
    }
}

enum GolemioClientError: LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case invalidRequest(String)
    case httpStatus(Int, String?)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Could not build the Golemio API URL."
        case .invalidResponse:
            return "Golemio returned an invalid response."
        case let .invalidRequest(message):
            return message
        case let .httpStatus(statusCode, body):
            if statusCode == 401 {
                return "The Golemio API token was rejected."
            }

            if let body, !body.isEmpty {
                return "Golemio returned HTTP \(statusCode): \(body)"
            }

            return "Golemio returned HTTP \(statusCode)."
        case let .decoding(error):
            return "Could not read Golemio response: \(Self.describeDecodingError(error))"
        }
    }

    private static func describeDecodingError(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return error.localizedDescription
        }

        switch decodingError {
        case let .keyNotFound(key, context):
            return "Missing field '\(key.stringValue)' at \(codingPathDescription(context.codingPath))."
        case let .typeMismatch(type, context):
            return "Expected \(type) at \(codingPathDescription(context.codingPath)): \(context.debugDescription)"
        case let .valueNotFound(type, context):
            return "Missing \(type) value at \(codingPathDescription(context.codingPath))."
        case let .dataCorrupted(context):
            return "Invalid data at \(codingPathDescription(context.codingPath)): \(context.debugDescription)"
        @unknown default:
            return error.localizedDescription
        }
    }

    private static func codingPathDescription(_ codingPath: [CodingKey]) -> String {
        let path = codingPath.map(\.stringValue).joined(separator: ".")
        return path.isEmpty ? "root" : path
    }
}

enum GolemioDateFormatters {
    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            if let date = iso8601WithFractionalSeconds.date(from: string) ?? iso8601.date(from: string) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected ISO 8601 date, got \(string)."
            )
        }
        return decoder
    }

    private static var iso8601WithFractionalSeconds: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    private static var iso8601: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }
}
