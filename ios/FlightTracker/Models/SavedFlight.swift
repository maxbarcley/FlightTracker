// Models/SavedFlight.swift
// SwiftData model for a flight saved to a trip.
// Caches last-known status locally for offline viewing.

import Foundation
import SwiftData

@Model
final class SavedFlight {
    var id: UUID
    var flightNumber: String       // e.g. "UA123"
    var scheduledDeparture: Date
    var originIATA: String         // e.g. "JFK"
    var destinationIATA: String    // e.g. "LHR"
    var originName: String         // e.g. "John F. Kennedy International"
    var destinationName: String
    var addedAt: Date

    // Cached live status — updated by background refresh
    var statusRaw: String          // "scheduled" | "active" | "landed" | "cancelled" | "delayed"
    var actualDeparture: Date?
    var actualArrival: Date?
    var estimatedArrival: Date?
    var delayMinutes: Int
    var gate: String?
    var terminal: String?
    var baggageClaim: String?
    var aircraftTailNumber: String?
    var aircraftType: String?
    var lastRefreshed: Date?

    // Relationship back to trip
    var trip: Trip?

    init(
        flightNumber: String,
        scheduledDeparture: Date,
        originIATA: String,
        destinationIATA: String,
        originName: String = "",
        destinationName: String = ""
    ) {
        self.id = UUID()
        self.flightNumber = flightNumber
        self.scheduledDeparture = scheduledDeparture
        self.originIATA = originIATA
        self.destinationIATA = destinationIATA
        self.originName = originName
        self.destinationName = destinationName
        self.addedAt = Date()
        self.statusRaw = "scheduled"
        self.delayMinutes = 0
    }

    var status: FlightStatus {
        FlightStatus(rawValue: statusRaw) ?? .scheduled
    }

    var isDelayed: Bool { delayMinutes > 15 }

    var statusColor: String {
        switch status {
        case .active:    return "green"
        case .landed:    return "blue"
        case .cancelled: return "red"
        case .delayed:   return "orange"
        default:         return "gray"
        }
    }
}

// MARK: - Flight Status Enum

enum FlightStatus: String, Codable {
    case scheduled
    case active
    case landed
    case cancelled
    case delayed
    case diverted
    case unknown

    var displayName: String {
        switch self {
        case .scheduled: return "Scheduled"
        case .active:    return "In Flight"
        case .landed:    return "Landed"
        case .cancelled: return "Cancelled"
        case .delayed:   return "Delayed"
        case .diverted:  return "Diverted"
        case .unknown:   return "Unknown"
        }
    }
}
