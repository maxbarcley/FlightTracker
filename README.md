# Flight Tracker — Full Stack Scaffold

A Flighty-inspired iOS flight tracking app. This repo contains:

- `ios/` — SwiftUI iOS app (Swift 5.10, iOS 17+, SwiftData)
- `backend/` — Node.js + Fastify back end server

---

## Quick Start

### 1. Back End

```bash
cd backend
cp .env.example .env
# Fill in your API keys in .env

npm install
npm run dev      # starts server on port 3000 with auto-reload
```

Then run the database migration in your Supabase SQL Editor:
`backend/db/migrations/001_initial.sql`

### 2. iOS App

1. Open `ios/FlightTracker/` in Xcode 16
2. Set your Team in Signing & Capabilities
3. Edit `Services/APIService.swift` → update `AppConfig.baseURL` to your Railway URL
4. Enable Push Notifications capability in Xcode
5. Run on simulator or device

---

## File Map

### iOS (`ios/FlightTracker/`)

| File | Purpose |
|------|---------|
| `FlightTrackerApp.swift` | App entry, SwiftData container, AppDelegate |
| `Models/Trip.swift` | SwiftData model for a trip |
| `Models/SavedFlight.swift` | SwiftData model for a saved flight |
| `Models/APIModels.swift` | Codable structs for API responses |
| `Services/APIService.swift` | All HTTP calls to your back end |
| `Services/NotificationService.swift` | Push notification permission + token registration |
| `ViewModels/TripListViewModel.swift` | Logic for trips list + flight search |
| `ViewModels/FlightDetailViewModel.swift` | Live refresh for flight detail screen |
| `Views/ContentView.swift` | Root tab bar |
| `Views/Trips/TripsView.swift` | Trip list |
| `Views/Trips/TripDetailView.swift` | Flights within a trip |
| `Views/Trips/AddFlightSheet.swift` | Search + add flight sheet |
| `Views/Flights/FlightDetailView.swift` | Full live flight detail |
| `Views/Flights/FlightMapView.swift` | MapKit map with route + aircraft marker |
| `Views/Airports/AirportInfoView.swift` | Airport stats, weather, delay chart |

### Back End (`backend/`)

| File | Purpose |
|------|---------|
| `server.js` | Fastify server entry point + auth hook |
| `routes/flights.js` | Flight search + detail endpoints |
| `routes/trips.js` | Create trips, add/remove flights |
| `routes/devices.js` | Register APNs device tokens |
| `routes/airports.js` | Airport stats + weather |
| `services/aeroDataBox.js` | AeroDataBox API wrapper |
| `services/opensky.js` | OpenSky Network live positions |
| `services/notifications.js` | APNs push via node-apn |
| `jobs/pollFlights.js` | Cron job: poll active flights every 60s |
| `db/migrations/001_initial.sql` | Supabase PostgreSQL schema |
| `.env.example` | All required environment variables |

---

## API Keys You Need

| Service | Where to get it | Cost |
|---------|----------------|------|
| AeroDataBox | rapidapi.com/aedbx-aedbx/api/aerodatabox | From $0.99/mo |
| OpenWeatherMap | openweathermap.org/api | Free tier |
| Supabase | supabase.com | Free tier |
| Apple APNs .p8 key | developer.apple.com (Certificates > Keys) | Free (needs $99/yr Developer account) |

---

## Next Features to Add

- [ ] Live Activities (lock screen widget) using ActivityKit
- [ ] Sign in with Apple integration (Supabase Auth)
- [ ] Calendar sync (EventKit)
- [ ] Widget extension for home screen
- [ ] Share trip with friends (read-only link)
