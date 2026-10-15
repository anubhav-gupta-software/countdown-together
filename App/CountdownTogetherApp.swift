import SwiftUI

@main
struct CountdownTogetherApp: App {
    @State private var repository = CountdownRepository()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(repository)
                .onOpenURL { url in
                    repository.handle(url: url)
                }
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    await repository.handleBecameActive()
                }
        }
    }
}
