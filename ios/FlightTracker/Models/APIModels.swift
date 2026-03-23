// Models/APIModels.swift
// Codable structs that mirror your back end's JSON responses.
// These are NOT SwiftData models — they're just for decoding API responses.

import Foundation

// MARK: - Flight Detail (from your back end /flights/{number})

struct FlightDetailResponse: Codable {
    let flightNumber: String
    let airline: AirlineInfo
    let origin: AirportInfo
    let destination: AirportInfo
    let departure: FlightTime
    let arrival: FlightTime
    let status: String
    let delayMinutes: Int
    let aircraft: AircraftInfo?
    let position: AircraftPosition?   // nil if not yet departed
    let inboundFlight: InboundFlightInfo?

    enum CodingKeys: String, CodingKey {
        case flightNumber = "flight_number"
        case airline, origin, destination, departure, arrival, status
        case delayMinutes = "delay_minutes"
        case aircraft, position
        case inboundFlight = "inbound_flight"
    }
}

struct AirlineInfo: Codable {
    let iata: String
    let name: String
    let logoUrl: String?

    enum CodingKeys: String, CodingKey {
        case iata, name
        case logoUrl = "logo_url"
    }
}

struct AirportInfo: Codable {
    let iata: String
    let icao: String
    let name: String
    let city: String
    let country: String
    let latitude: Double
    let longitude: Double
    let terminal: String?
    let gate: String?
    let baggageClaim: String?

    enum CodingKeys: String, CodingKey {
        case iata, icao, name, city, country, latitude, longitude
        case terminal, gate
        case baggageClaim = "baggage_claim"
    }
}

struct FlightTime: Codable {
    let scheduled: Date
    let actual: Date?
    let estimated: Date?
}

struct AircraftInfo: Codable {
    let tailNumber: String?
    let model: String?
    let manufacturer: String?

    enum CodingKeys: String, CodingKey {
        case tailNumber = "tail_number"
        case model, manufacturer
    }
}

// MARK: - Live Aircraft Position (from your back end, sourced from OpenSky)

struct AircraftPosition: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Int        // feet
    let speed: Int           // knots
    let heading: Double      // degrees 0–360
    let verticalRate: Int    // feet per minute (positive = climbing)
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case latitude, longitude, altitude, speed, heading
        case verticalRate = "vertical_rate"
        case timestamp
    }
}

// MARK: - Inbound ("Where's My Plane?") Info

struct InboundFlightInfo: Codable {
    let flightNumber: String
    let originIATA: String
    let status: String
    let estimatedArrival: Date?
    let delayMinutes: Int

    enum CodingKeys: String, CodingKey {
        case flightNumber = "flight_number"
        case originIATA = "origin_iata"
        case status
        case estimatedArrival = "estimated_arrival"
        case delayMinutes = "delay_minutes"
    }
}

// MARK: - Airport Stats

struct AirportStatsResponse: Codable {
    let iata: String
    let name: String
    let onTimePercentage: Double
    let averageDelayMinutes: Int
    let weather: WeatherInfo?
    let topDelayReasons: [DelayReason]

    enum CodingKeys: String, CodingKey {
        case iata, name
        case onTimePercentage = "on_time_percentage"
        case averageDelayMinutes = "average_delay_minutes"
        case weather
        case topDelayReasons = "top_delay_reasons"
    }
}

struct WeatherInfo: Codable {
    let description: String
    let temperatureCelsius: Double
    let windSpeedKph: Double
    let icon: String

    enum CodingKeys: String, CodingKey {
        case description
        case temperatureCelsius = "temperature_celsius"
        case windSpeedKph = "wind_speed_kph"
        case icon
    }

    var temperatureFahrenheit: Double {
        temperatureCelsius * 9 / 5 + 32
    }
}

struct DelayReason: Codable {
    let reason: String
    let percentage: Double
}

// MARK: - Flight Search Result (for adding flights to trips)

struct FlightSearchResult: Codable, Identifiable {
    let id: String          // flight_number + date
    let flightNumber: String
    let originIATA: String
    let destinationIATA: String
    let originCity: String
    let destinationCity: String
    let scheduledDeparture: Date
    let scheduledArrival: Date
    let airline: String

    enum CodingKeys: String, CodingKey {
        case id
        case flightNumber = "flight_number"
        case originIATA = "origin_iata"
        case destinationIATA = "destination_iata"
        case originCity = "origin_city"
        case destinationCity = "destination_city"
        case scheduledDeparture = "scheduled_departure"
        case scheduledArrival = "scheduled_arrival"
        case airline
    }
}

// MARK: - API Error

struct APIError: Codable, LocalizedError {
    let code: String
    let message: String

    var errorDescription: String? { message }
}
