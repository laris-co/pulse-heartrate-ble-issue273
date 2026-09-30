import SwiftUI

@main
struct PulseApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = PulseStore()

    var body: some Scene {
        WindowGroup {
            PulseView(store: store)
                .onOpenURL { url in
                    _ = store.handleConnectIQURL(url)
                }
        }
        .onChange(of: scenePhase) { _, phase in
            store.handleScenePhase(phase)
        }
    }
}
