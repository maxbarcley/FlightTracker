// Models/Trip.swift
// SwiftData model representing a travel trip containing one or more flights.

import Foundation
import SwiftData

@Model
final class Trip {
    var id: UUID
    var name: String               // e.g. "NYC → London June 2026"
    var createdAt: Date
    var flights: [SavedFlight]     // Flights in this trip, sorted by departure

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.flights = []
    }

    /// Returns flights sorted by scheduled departure time
    var sortedFlights: [SavedFlight] {
        flights.sorted { $0.scheduledDeparture < $1.scheduledDeparture }
    }

    /// Next upcoming or active flight
    var activeFlight: SavedFlight? {
        sortedFlights.first { $0.scheduledDeparture > Date().addingTimeInterval(-7200) }
    }
}
