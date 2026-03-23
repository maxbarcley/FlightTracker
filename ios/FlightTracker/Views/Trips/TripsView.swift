// Views/Trips/TripsView.swift
// Main trips list — shows all saved trips and their active flight status.

import SwiftUI
import SwiftData

struct TripsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    @State private var viewModel = TripListViewModel()
    @State private var showingNewTrip = false
    @State private var newTripName = ""

    var body: some View {
        NavigationStack {
            Group {
                if trips.isEmpty {
                    EmptyTripsView {
                        showingNewTrip = true
                    }
                } else {
                    List {
                        ForEach(trips) { trip in
                            NavigationLink(destination: TripDetailView(trip: trip)) {
                                TripRowView(trip: trip)
                            }
                        }
                        .onDelete(perform: deleteTrips)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Trips")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewTrip = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New Trip", isPresented: $showingNewTrip) {
                TextField("Trip name", text: $newTripName)
                Button("Create") {
                    if !newTripName.isEmpty {
                        viewModel.createTrip(name: newTripName, in: modelContext)
                        newTripName = ""
                    }
                }
                Button("Cancel", role: .cancel) { newTripName = "" }
            } message: {
                Text("Give your trip a name, e.g. \"NYC → London June 2026\"")
            }
        }
    }

    private func deleteTrips(at offsets: IndexSet) {
        for index in offsets {
            viewModel.deleteTrip(trips[index], from: modelContext)
        }
    }
}

// MARK: - Trip Row

struct TripRowView: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(trip.name)
                .font(.headline)

            if let active = trip.activeFlight {
                HStack(spacing: 6) {
                    FlightStatusBadge(status: FlightStatus(rawValue: active.statusRaw) ?? .scheduled)
                    Text(active.flightNumber)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("\(active.originIATA) → \(active.destinationIATA)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("\(trip.flights.count) flight\(trip.flights.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Empty State

struct EmptyTripsView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 72))
                .foregroundStyle(.blue.gradient)
            Text("No trips yet")
                .font(.title2.bold())
            Text("Add your first trip to start tracking flights and get real-time alerts.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Add a Trip") {
                onAdd()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

// MARK: - Status Badge

struct FlightStatusBadge: View {
    let status: FlightStatus

    var color: Color {
        switch status {
        case .active:    return .green
        case .landed:    return .blue
        case .cancelled: return .red
        case .delayed:   return .orange
        default:         return .gray
        }
    }

    var body: some View {
        Text(status.displayName)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
