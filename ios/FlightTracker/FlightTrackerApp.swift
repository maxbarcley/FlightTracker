// FlightTrackerApp.swift
// Entry point for the Flight Tracker iOS app.
// Sets up SwiftData container and root navigation.

import SwiftUI
import SwiftData
import UserNotifications

@main
struct FlightTrackerApp: App {

    // SwiftData model container — stores trips and flights locally on device
    let modelContainer: ModelContainer = {
        let schema = Schema([Trip.self, SavedFlight.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
        }
    }
}

// MARK: - App Delegate (needed for push notification registration)

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Called when APNs successfully registers — send the token to your back end
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Task {
            await NotificationService.shared.registerDeviceToken(token)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for push notifications: \(error)")
    }

    // Handle notification tap when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // Handle tap on notification (app was closed or in background)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let flightId = userInfo["flightId"] as? String {
            NotificationCenter.default.post(
                name: .openFlightDetail,
                object: nil,
                userInfo: ["flightId": flightId]
            )
        }
        completionHandler()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openFlightDetail = Notification.Name("openFlightDetail")
}
