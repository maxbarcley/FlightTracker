// Views/Flights/FlightDetailView.swift
// Full live detail view for a single flight — status, map, inbound aircraft, airport info.

import SwiftUI
import MapKit

struct FlightDetailView: View {
    let flight: SavedFlight
    @State private var viewModel: FlightDetailViewModel

    init(flight: SavedFlight) {
        self.flight = flight
        self._viewModel = State(initialValue: FlightDetailViewModel(flight: flight))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Map
                FlightMapView(
                    origin: viewModel.detail?.origin,
                    destination: viewModel.detail?.destination,
                    position: viewModel.position
                )
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 0))

                VStack(spacing: 16) {
                    // Status card
                    StatusCard(flight: flight, viewModel: viewModel)

                    // Route card
                    if let detail = viewModel.detail {
                        RouteCard(detail: detail)
                    }

                    // "Where's my plane?" card
                    if let inbound = viewModel.detail?.inboundFlight {
                        InboundFlightCard(inbound: inbound)
                    }

                    // Aircraft info
                    if let aircraft = viewModel.detail?.aircraft {
                        AircraftCard(aircraft: aircraft, position: viewModel.position)
                    }

                    // Airport info links
                    if let detail = viewModel.detail {
                        HStack(spacing: 12) {
                            NavigationLink(destination: AirportInfoView(iata: detail.origin.iata)) {
                                AirportLinkCard(iata: detail.origin.iata, city: detail.origin.city)
                            }
                            NavigationLink(destination: AirportInfoView(iata: detail.destination.iata)) {
                                AirportLinkCard(iata: detail.destination.iata, city: detail.destination.city)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle(flight.flightNumber)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .task {
            viewModel.startTracking()
        }
        .onDisappear {
            viewModel.stopTracking()
        }
    }
}

// MARK: - Status Card

struct StatusCard: View {
    let flight: SavedFlight
    let viewModel: FlightDetailViewModel

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                FlightStatusBadge(status: flight.status)
                Spacer()
                if let delay = viewModel.delayText {
                    Text(delay)
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                }
            }

            // Progress bar (only when in flight)
            if flight.status == .active {
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 6)
                            Capsule()
                                .fill(Color.blue.gradient)
                                .frame(width: geo.size.width * viewModel.progressFraction, height: 6)
                        }
                    }
                    .frame(height: 6)
                    HStack {
                        Text(flight.originIATA).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        if let alt = viewModel.altitudeText, let spd = viewModel.speedText {
                            Text("\(alt)  •  \(spd)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(flight.destinationIATA).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .padding(.horizontal)
    }
}

// MARK: - Route Card

struct RouteCard: View {
    let detail: FlightDetailResponse

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(detail.origin.iata)
                    .font(.largeTitle.bold())
                Text(detail.origin.city)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(timeFormatter.string(from: detail.departure.actual ?? detail.departure.scheduled))
                    .font(.headline)
                if let terminal = detail.origin.terminal {
                    Label("Terminal \(terminal)", systemImage: "building.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let gate = detail.origin.gate {
                    Label("Gate \(gate)", systemImage: "door.right.hand.open")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(spacing: 2) {
                Image(systemName: "airplane")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(detail.destination.iata)
                    .font(.largeTitle.bold())
                Text(detail.destination.city)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(timeFormatter.string(from: detail.arrival.estimated ?? detail.arrival.scheduled))
                    .font(.headline)
                if let terminal = detail.destination.terminal {
                    Label("Terminal \(terminal)", systemImage: "building.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let baggage = detail.destination.baggageClaim {
                    Label("Carousel \(baggage)", systemImage: "suitcase.rolling.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .padding(.horizontal)
    }
}

// MARK: - Inbound Flight ("Where's My Plane?") Card

struct InboundFlightCard: View {
    let inbound: InboundFlightInfo

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "airplane.arrival")
                .font(.title2)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("Where's my plane?")
                    .font(.headline)
                Text("Inbound as \(inbound.flightNumber) from \(inbound.originIATA)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if inbound.delayMinutes > 0 {
                    Text("Running \(inbound.delayMinutes)min late — your flight may be delayed")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            FlightStatusBadge(status: FlightStatus(rawValue: inbound.status) ?? .scheduled)
        }
        .padding()
        .background(Color.blue.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

// MARK: - Aircraft Card

struct AircraftCard: View {
    let aircraft: AircraftInfo
    let position: AircraftPosition?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "airplane.circle.fill")
                .font(.title)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(aircraft.model ?? "Unknown aircraft")
                    .font(.headline)
                if let tail = aircraft.tailNumber {
                    Text(tail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let pos = position {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(pos.altitude.formatted())ft")
                        .font(.subheadline)
                    Text("\(pos.speed)kts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .padding(.horizontal)
    }
}

// MARK: - Airport Link Card

struct AirportLinkCard: View {
    let iata: String
    let city: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(iata)
                .font(.title2.bold())
            Text(city)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Airport info →")
                .font(.caption2)
                .foregroundStyle(.blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }
}
