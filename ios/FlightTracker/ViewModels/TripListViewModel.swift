// ViewModels/TripListViewModel.swift
// Manages the list of trips and adding new flights.

import Foundation
import SwiftData
import Observation

@Observable
class TripListViewModel {

    var isAddingFlight = false
    var searchQuery = ""
    var searchResults: [FlightSearchResult] = []
    var isSearching = false
    var searchError: String?
    var selectedDate: Date = Date()

    // MARK: - Trip Management

    func createTrip(name: String, in context: ModelContext) {
        let trip = Trip(name: name)
        context.insert(trip)
        try? context.save()
    }

    func deleteTrip(_ trip: Trip, from context: ModelContext) {
        context.delete(trip)
        try? context.save()
    }

    // MARK: - Flight Search

    @MainActor
    func searchFlights() async {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        searchError = nil
        do {
            searchResults = try await APIService.shared.searchFlight(
                number: searchQuery.uppercased(),
                date: selectedDate
            )
        } catch {
            searchError = error.localizedDescription
            searchResults = []
        }
        isSearching = false
    }

    // MARK: - Add Flight to Trip

    @MainActor
    func addFlight(_ result: FlightSearchResult, to trip: Trip, in context: ModelContext) async {
        // Save locally to SwiftData immediately (optimistic update)
        let flight = SavedFlight(
            flightNumber: result.flightNumber,
            scheduledDeparture: result.scheduledDeparture,
            originIATA: result.originIATA,
            destinationIATA: result.destinationIATA,
            originName: result.originCity,
            destinationName: result.destinationCity
        )
        flight.trip = trip
        trip.flights.append(flight)
        context.insert(flight)
        try? context.save()

        // Also register on the server (enables push notifications for this flight)
        do {
            await APIService.shared.addFlightToTrip(
                tripId: trip.id.uuidString,
                flightNumber: result.flightNumber,
                date: result.scheduledDeparture
            )
        } catch {
            print("Failed to register flight on server: \(error)")
            // Non-fatal: local data still saved; notifications won't work until retried
        }

        isAddingFlight = false
    }
}

// Small async wrapper to silence warning about unhandled throws
private extension TripListViewModel {
    @discardableResult
    func addFlightToTrip(tripId: String, flightNumber: String, date: Date) async -> Bool {
        do {
            try await APIService.shared.addFlightToTrip(tripId: tripId, flightNumber: flightNumber, date: date)
            return true
        } catch {
            return false
        }
    }
}
