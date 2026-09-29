import SwiftUI

@main
struct PulseHeartRateBLEApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var bluetooth = HeartRateBluetoothManager()
    @StateObject private var notifications = DiagnosticNotificationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bluetooth)
                .environmentObject(notifications)
        }
        .onChange(of: scenePhase) { _, newPhase in
            bluetooth.handleScenePhase(newPhase)
        }
    }
}
