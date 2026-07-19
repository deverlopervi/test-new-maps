import SwiftUI

@main
struct MuleHazardMapApp: App {
    @StateObject private var authStore = AuthStore()
    @StateObject private var syncEngine = SyncEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authStore)
                .environmentObject(syncEngine)
                .task {
                    await syncEngine.configure(authStore: authStore)
                }
        }
    }
}
