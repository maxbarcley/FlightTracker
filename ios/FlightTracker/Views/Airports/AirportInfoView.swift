// Views/Airports/AirportInfoView.swift
// Airport detail — on-time stats, weather, and terminal info.

import SwiftUI
import Charts

struct AirportInfoView: View {
    let iata: String

    @State private var stats: AirportStatsResponse?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading airport info…")
                    .frame(maxWidth: .infinity, minHeight: 300)
            } else if let error {
                ContentUnavailableView(
                    "Couldn't load airport info",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if let stats {
                VStack(spacing: 16) {
                    // On-time summary card
                    OnTimeSummaryCard(stats: stats)

                    // Weather card
                    if let weather = stats.weather {
                        WeatherCard(iata: iata, weather: weather)
                    }

                    // Delay reasons chart
                    if !stats.topDelayReasons.isEmpty {
                        DelayReasonsCard(reasons: stats.topDelayReasons)
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle(iata)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadStats()
        }
    }

    private func loadStats() async {
        isLoading = true
        error = nil
        do {
            stats = try await APIService.shared.getAirportStats(iata: iata)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - On-Time Summary Card

struct OnTimeSummaryCard: View {
    let stats: AirportStatsResponse

    var onTimeColor: Color {
        switch stats.onTimePercentage {
        case 80...: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(stats.name)
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(stats.onTimePercentage))%")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(onTimeColor)
                Text("on time")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 10)
                    Capsule()
                        .fill(onTimeColor.gradient)
                        .frame(width: geo.size.width * (stats.onTimePercentage / 100), height: 10)
                }
            }
            .frame(height: 10)

            Text("Average delay when late: \(stats.averageDelayMinutes) minutes")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .padding(.horizontal)
    }
}

// MARK: - Weather Card

struct WeatherCard: View {
    let iata: String
    let weather: WeatherInfo

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Weather")
                    .font(.headline)
                Text(weather.description.capitalized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(weather.temperatureFahrenheit))°F")
                    .font(.title2.bold())
                Text("\(Int(weather.windSpeedKph)) km/h wind")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

// MARK: - Delay Reasons Chart

struct DelayReasonsCard: View {
    let reasons: [DelayReason]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Delay Reasons")
                .font(.headline)

            Chart(reasons, id: \.reason) { reason in
                BarMark(
                    x: .value("Percentage", reason.percentage),
                    y: .value("Reason", reason.reason)
                )
                .foregroundStyle(.blue.gradient)
            }
            .chartXAxis {
                AxisMarks(format: Decimal.FormatStyle.Percent.percent)
            }
            .frame(height: 180)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .padding(.horizontal)
    }
}
