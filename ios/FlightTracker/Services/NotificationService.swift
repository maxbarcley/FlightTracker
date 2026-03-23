// Services/NotificationService.swift
// Handles push notification permission requests and device token registration.

import Foundation
import UserNotifications
import UIKit

@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()
    private init() {}

    @Published var permissionStatus: UNAuthorizationStatus = .notDetermined

    /// Call this on app launch and when the user explicitly requests notifications
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await checkStatus()
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }

    func checkStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionStatus = settings.authorizationStatus
    }

    /// Sends the APNs device token to your back end for storage
    func registerDeviceToken(_ token: String) async {
        guard AppConfig.authToken != nil else { return } // Must be signed in

        struct Body: Encodable { let token: String }
        guard let url = URL(string: AppConfig.baseURL + "/devices/register") else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let authToken = AppConfig.authToken {
            req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try? JSONEncoder().encode(Body(token: token))

        _ = try? await URLSession.shared.data(for: req)
    }

    /// Configure local notification categories (for actionable notifications)
    func setupNotificationCategories() {
        let viewAction = UNNotificationAction(
            identifier: "VIEW_FLIGHT",
            title: "View Flight",
            options: .foreground
        )
        let flightCategory = UNNotificationCategory(
            identifier: "FLIGHT_UPDATE",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([flightCategory])
    }
}
