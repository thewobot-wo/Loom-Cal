import SwiftUI
import ConvexMobile

// Global ConvexClient singleton — one instance per process (never create inside a ViewModel)
// Source: https://docs.convex.dev/quickstart/swift
let convex = ConvexClient(deploymentUrl: ConvexEnv.deploymentUrl)

@main
struct LoomCalApp: App {
    @StateObject private var eventKitService = EventKitService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(eventKitService)
        }
    }
}
