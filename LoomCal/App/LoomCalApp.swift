import SwiftUI
import ConvexMobile

// Global ConvexClient singleton — one instance per process (never create inside a ViewModel)
// Source: https://docs.convex.dev/quickstart/swift
let convex = ConvexClient(deploymentUrl: ConvexEnv.deploymentUrl)

@main
struct LoomCalApp: App {
    @StateObject private var eventKitService = EventKitService()

    // Touch the singleton early so its UNUserNotificationCenterDelegate is set
    // before any notifications are scheduled.
    private let notificationService = NotificationService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(eventKitService)
                .task {
                    await NotificationService.shared.requestPermission()
                }
        }
    }
}
