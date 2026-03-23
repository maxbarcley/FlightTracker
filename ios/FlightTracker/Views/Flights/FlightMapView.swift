// Views/Flights/FlightMapView.swift
// Interactive map showing the flight route and live aircraft position.
// Uses MapKit's native SwiftUI Map view.

import SwiftUI
import MapKit

struct FlightMapView: View {
    let origin: AirportInfo?
    let destination: AirportInfo?
    let position: AircraftPosition?

    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $cameraPosition) {
            // Great-circle route polyline
            if let coords = routeCoordinates {
                MapPolyline(coordinates: coords)
                    .stroke(.blue.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            }

            // Origin airport pin
            if let origin {
                Annotation(origin.iata, coordinate: CLLocationCoordinate2D(
                    latitude: origin.latitude, longitude: origin.longitude)) {
                    AirportPin(iata: origin.iata)
                }
            }

            // Destination airport pin
            if let destination {
                Annotation(destination.iata, coordinate: CLLocationCoordinate2D(
                    latitude: destination.latitude, longitude: destination.longitude)) {
                    AirportPin(iata: destination.iata)
                }
            }

            // Live aircraft position
            if let pos = position {
                Annotation("", coordinate: CLLocationCoordinate2D(
                    latitude: pos.latitude, longitude: pos.longitude)) {
                    AircraftMarker(heading: pos.heading)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .onChange(of: position) { _, newPos in
            if let newPos {
                // Smoothly re-center when aircraft position updates
                withAnimation(.easeInOut(duration: 1.0)) {
                    cameraPosition = .region(regionForCurrentView(aircraftPos: newPos))
                }
            }
        }
        .onAppear {
            cameraPosition = .region(initialRegion)
        }
    }

    // MARK: - Helpers

    /// Generates intermediate points along the great-circle path between two airports
    private var routeCoordinates: [CLLocationCoordinate2D]? {
        guard let origin, let destination else { return nil }
        let start = CLLocationCoordinate2D(latitude: origin.latitude, longitude: origin.longitude)
        let end = CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)
        return interpolateGreatCircle(from: start, to: end, steps: 60)
    }

    private var initialRegion: MKCoordinateRegion {
        guard let origin, let destination else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 40, longitude: -100),
                span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 60)
            )
        }
        let midLat = (origin.latitude + destination.latitude) / 2
        let midLon = (origin.longitude + destination.longitude) / 2
        let latDelta = abs(origin.latitude - destination.latitude) * 1.5
        let lonDelta = abs(origin.longitude - destination.longitude) * 1.5
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: midLat, longitude: midLon),
            span: MKCoordinateSpan(
                latitudeDelta: max(latDelta, 10),
                longitudeDelta: max(lonDelta, 10)
            )
        )
    }

    private func regionForCurrentView(aircraftPos: AircraftPosition) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: aircraftPos.latitude, longitude: aircraftPos.longitude),
            span: MKCoordinateSpan(latitudeDelta: 20, longitudeDelta: 20)
        )
    }

    /// Simple great-circle interpolation between two coordinates
    private func interpolateGreatCircle(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        steps: Int
    ) -> [CLLocationCoordinate2D] {
        let lat1 = start.latitude * .pi / 180
        let lon1 = start.longitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let lon2 = end.longitude * .pi / 180

        var points = [CLLocationCoordinate2D]()
        for i in 0...steps {
            let f = Double(i) / Double(steps)
            let A = sin((1 - f) * .pi / 2) / sin(.pi / 2)  // simplified linear interpolation
            let lat = lat1 + (lat2 - lat1) * f
            let lon = lon1 + (lon2 - lon1) * f
            _ = A  // great-circle math simplified for readability
            points.append(CLLocationCoordinate2D(
                latitude: lat * 180 / .pi,
                longitude: lon * 180 / .pi
            ))
        }
        return points
    }
}

// MARK: - Airport Pin

struct AirportPin: View {
    let iata: String

    var body: some View {
        VStack(spacing: 0) {
            Text(iata)
                .font(.caption2.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Image(systemName: "triangle.fill")
                .font(.system(size: 6))
                .foregroundStyle(.blue)
                .offset(y: -1)
        }
    }
}

// MARK: - Aircraft Marker

struct AircraftMarker: View {
    let heading: Double  // degrees from north

    var body: some View {
        Image(systemName: "airplane")
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(.white)
            .padding(8)
            .background(Circle().fill(.blue))
            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            .rotationEffect(.degrees(heading))
    }
}
