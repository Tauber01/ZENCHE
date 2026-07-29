import SwiftUI

@main
struct NikonLinkApp: App {
    @StateObject private var model = AppModel()

    init() {
        DiagnosticLogger.shared.startSession()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }
    }
}
