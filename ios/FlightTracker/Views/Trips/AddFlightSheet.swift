// Views/Trips/AddFlightSheet.swift
// Sheet for searching and adding a flight to a trip.

import SwiftUI
import SwiftData

struct AddFlightSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let trip: Trip
    @Bindable var viewModel: TripListViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar + date
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Flight number, e.g. UA123", text: $viewModel.searchQuery)
                            .textInputAutocapitalization(.characters)
                            .disableAutocorrection(true)
                            .submitLabel(.search)
                            .onSubmit { Task { await viewModel.searchFlights() } }
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    DatePicker(
                        "Departure date",
                        selection: $viewModel.selectedDate,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                }
                .padding()

                Divider()

                // Results
                Group {
                    if viewModel.isSearching {
                        ProgressView("Searching...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let errorMsg = viewModel.searchError {
                        ContentUnavailableView(
                            "Search failed",
                            systemImage: "exclamationmark.triangle",
                            description: Text(errorMsg)
                        )
                    } else if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty {
                        ContentUnavailableView(
                            "No flights found",
                            systemImage: "airplane.slash",
                            description: Text("Try a different flight number or date.")
                        )
                    } else {
                        List(viewModel.searchResults) { result in
                            SearchResultRow(result: result) {
                                Task {
                                    await viewModel.addFlight(result, to: trip, in: modelContext)
                                    dismiss()
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("Add Flight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Search") {
                        Task { await viewModel.searchFlights() }
                    }
                    .disabled(viewModel.searchQuery.isEmpty)
                }
            }
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let result: FlightSearchResult
    let onAdd: () -> Void

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(result.flightNumber)
                        .font(.headline)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(result.airline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("\(result.originIATA) → \(result.destinationIATA)")
                        .font(.subheadline)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("\(timeFormatter.string(from: result.scheduledDeparture))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("\(result.originCity) → \(result.destinationCity)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button {
                onAdd()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
