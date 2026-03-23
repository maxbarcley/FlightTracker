// Services/APIService.swift
// All network calls to YOUR back end server.
// Never calls flight data APIs directly — those are proxied through the server
// to keep API keys secret and centralize caching.

import Foundation

// MARK: - Configuration

enum AppConfig {
    /// Replace with your Railway/Render URL once deployed
    static let baseURL = "https://your-backend.railway.app"

    /// Auth token — set after the user signs in (Supabase JWT)
    static var authToken: String? = nil
}

// MARK: - API Service

@MainActor
class APIService: ObservableObject {
    static let shared = APIService()
    private init() {}

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    // MARK: - Generic Request

    private func request<T: Decodable>(
        path: String,
        method: String = "GET",
        body: Encodable? = nil
    ) async throws -> T {
        guard let url = URL(string: AppConfig.baseURL + path) else {
            throw URLError(.badURL)
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AppConfig.authToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            // Try to decode an error message from the server
            if let apiError = try? decoder.decode(APIError.self, from: data) {
                throw apiError
            }
            throw URLError(.badServerResponse)
        }

        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Flight Endpoints

    /// Look up a flight by number and date to preview before adding to a trip
    func searchFlight(number: String, date: Date) async throws -> [FlightSearchResult] {
        let dateStr = ISO8601DateFormatter().string(from: date).prefix(10)
        return try await request(path: "/flights/search?number=\(number)&date=\(dateStr)")
    }

    /// Get full live detail for a specific flight
    func getFlightDetail(flightNumber: String, date: Date) async throws -> FlightDetailResponse {
        let dateStr = ISO8601DateFormatter().string(from: date).prefix(10)
        return try await request(path: "/flights/\(flightNumber)?date=\(dateStr)")
    }

    /// Get live aircraft position for the map (calls OpenSky via your server)
    func getAircraftPosition(flightNumber: String) async throws -> AircraftPosition? {
        struct PositionResponse: Codable { let position: AircraftPosition? }
        let resp: PositionResponse = try await request(path: "/flights/\(flightNumber)/position")
        return resp.position
    }

    // MARK: - Airport Endpoints

    func getAirportStats(iata: String) async throws -> AirportStatsResponse {
        return try await request(path: "/airports/\(iata)/stats")
    }

    // MARK: - Trip Endpoints

    struct CreateTripBody: Encodable {
        let name: String
    }

    struct TripResponse: Decodable {
        let id: String
        let name: String
        let createdAt: Date
        enum CodingKeys: String, CodingKey {
            case id, name
            case createdAt = "created_at"
        }
    }

    func createTripOnServer(name: String) async throws -> TripResponse {
        return try await request(
            path: "/trips",
            method: "POST",
            body: CreateTripBody(name: name)
        )
    }

    struct AddFlightBody: Encodable {
        let flightNumber: String
        let date: String
        enum CodingKeys: String, CodingKey {
            case flightNumber = "flight_number"
            case date
        }
    }

    func addFlightToTrip(tripId: String, flightNumber: String, date: Date) async throws {
        let dateStr = String(ISO8601DateFormatter().string(from: date).prefix(10))
        let _: EmptyResponse = try await request(
            path: "/trips/\(tripId)/flights",
            method: "POST",
            body: AddFlightBody(flightNumber: flightNumber, date: dateStr)
        )
    }

    struct EmptyResponse: Decodable {}
}
