// ViewModels/FlightDetailViewModel.swift
// Drives the flight detail screen: live status, map position, inbound aircraft.

import Foundation
import Observation
import Combine

@Observable
class FlightDetailViewModel {

    var detail: FlightDetailResponse?
    var position: AircraftPosition?
    var isLoading = false
    var error: String?

    private var refreshTask: Task<Void, Never>?
    private let flight: SavedFlight

    init(flight: SavedFlight) {
        self.flight = flight
    }

    // MARK: - Load & Auto-Refresh

    func startTracking() {
        loadDetail()
        scheduleAutoRefresh()
    }

    func stopTracking() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    @MainActor
    private func loadDetail() {
        Task {
            isLoading = detail == nil
            error = nil
            do {
                async let detailFetch = APIService.shared.getFlightDetail(
                    flightNumber: flight.flightNumber,
                    date: flight.scheduledDeparture
                )
                async let positionFetch = APIService.shared.getAircraftPosition(
                    flightNumber: flight.flightNumber
                )
                let (newDetail, newPosition) = try await (detailFetch, positionFetch)
                detail = newDetail
                position = newPosition
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func scheduleAutoRefresh() {
        refreshTask = Task {
            while !Task.isCancelled {
                // Refresh every 30 seconds while the view is open
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                await loadDetail()
            }
        }
    }

    // MARK: - Computed Properties for Views

    var statusText: String {
        detail.map { FlightStatus(rawValue: $0.status)?.displayName ?? $0.status }
            ?? FlightStatus(rawValue: flight.statusRaw)?.displayName
            ?? "Loading..."
    }

    var delayText: String? {
        let minutes = detail?.delayMinutes ?? flight.delayMinutes
        guard minutes > 0 else { return nil }
        if minutes < 60 { return "\(minutes) min delay" }
        let hours = minutes / 60
        let mins = minutes % 60
        return mins == 0 ? "\(hours)h delay" : "\(hours)h \(mins)m delay"
    }

    var progressFraction: Double {
        guard let dep = detail?.departure.actual ?? detail?.departure.scheduled,
              let arr = detail?.arrival.estimated ?? detail?.arrival.scheduled else { return 0 }
        let total = arr.timeIntervalSince(dep)
        let elapsed = Date().timeIntervalSince(dep)
        return max(0, min(1, elapsed / total))
    }

    var altitudeText: String? {
        guard let alt = position?.altitude else { return nil }
        return "\(alt.formatted())ft"
    }

    var speedText: String? {
        guard let spd = position?.speed else { return nil }
        return "\(spd)kts"
    }
}
