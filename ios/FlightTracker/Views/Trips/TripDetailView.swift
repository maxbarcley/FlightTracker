// Views/Trips/TripDetailView.swift
// Shows all flights in a trip. Lets user add flights.

import SwiftUI
import SwiftData

struct TripDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var trip: Trip
    @State private var viewModel = TripListViewModel()
    @State private var showingAddFlight = false

    var body: some View {
        List {
            if trip.sortedFlights.isEmpty {
                ContentUnavailableView {
                    Label("No flights yet", systemImage: "airplane")
                } description: {
                    Text("Add a flight to this trip to start tracking it.")
                } actions: {
                    Button("Add Flight") { showingAddFlight = true }
                }
            } else {
                ForEach(trip.sortedFlights) { flight in
                    NavigationLink(destination: FlightDetailView(flight: flight)) {
                        FlightRowView(flight: flight)
                    }
                }
                .onDelete(perform: deleteFlights)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddFlight = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddFlight) {
            AddFlightSheet(trip: trip, viewModel: viewModel)
        }
    }

    private func deleteFlights(at offsets: IndexSet) {
        let sorted = trip.sortedFlights
        for index in offsets {
            let flight = sorted[index]
            trip.flights.removeAll { $0.id == flight.id }
            modelContext.delete(flight)
        }
        try? modelContext.save()
    }
}

// MARK: - Flight Row

struct FlightRowView: View {
    let flight: SavedFlight

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(flight.flightNumber)
                    .font(.headline)
                Spacer()
                FlightStatusBadge(status: flight.status)
                if flight.isDelayed {
                    Text("+\(flight.delayMinutes)m")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
            }

            HStack(spacing: 0) {
                VStack(alignment: .leading) {
                    Text(flight.originIATA)
                        .font(.title2.bold())
                    Text(timeFormatter.string(from: flight.scheduledDeparture))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(spacing: 2) {
                    Image(systemName: "airplane")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(dateFormatter.string(from: flight.scheduledDeparture))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text(flight.destinationIATA)
                        .font(.title2.bold())
                    if let eta = flight.estimatedArrival {
                        Text(timeFormatter.string(from: eta))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let gate = flight.gate {
                Label("Gate \(gate)", systemImage: "door.right.hand.open")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
