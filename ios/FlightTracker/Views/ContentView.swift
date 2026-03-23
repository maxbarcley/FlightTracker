// Views/ContentView.swift
// Root view — tab bar with Trips, Explore, and Settings tabs.

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var flightIdToOpen: String?

    var body: some View {
        TabView(selection: $selectedTab) {
            TripsView()
                .tabItem {
                    Label("Trips", systemImage: "suitcase.fill")
                }
                .tag(0)

            ExploreView()
                .tabItem {
                    Label("Explore", systemImage: "magnifyingglass")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .tint(.blue)
        // Deep link: notification tap opens correct flight
        .onReceive(NotificationCenter.default.publisher(for: .openFlightDetail)) { notification in
            if let id = notification.userInfo?["flightId"] as? String {
                flightIdToOpen = id
                selectedTab = 0
            }
        }
    }
}

// MARK: - Placeholder Views (implement in their own files)

struct ExploreView: View {
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "airplane.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue.gradient)
                Text("Search any flight")
                    .font(.headline)
                Text("Enter a flight number to track it live, even without adding it to a trip.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .navigationTitle("Explore")
            .searchable(text: $searchText, prompt: "Flight number, e.g. UA123")
        }
    }
}

struct SettingsView: View {
    @StateObject private var notifService = NotificationService.shared

    var body: some View {
        NavigationStack {
            List {
                Section("Notifications") {
                    HStack {
                        Label("Push Alerts", systemImage: "bell.fill")
                        Spacer()
                        switch notifService.permissionStatus {
                        case .authorized:
                            Text("On").foregroundStyle(.green)
                        case .denied:
                            Text("Denied").foregroundStyle(.red)
                        default:
                            Button("Enable") {
                                Task { await notifService.requestPermission() }
                            }
                        }
                    }
                }
                Section("Account") {
                    Label("Sign in with Apple", systemImage: "applelogo")
                }
                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                }
            }
            .navigationTitle("Settings")
            .task { await notifService.checkStatus() }
        }
    }
}
