import SwiftUI

/// Point d'entrée de l'application (100 % Swift / SwiftUI, cible visionOS).
@main
struct Visionpro3DViewerApp: App {
    @StateObject private var store = SceneStateStore()
    @StateObject private var session = ViewerSession()

    var body: some Scene {
        // Fenêtre volumétrique : plus adaptée à la visualisation 3D sur Vision Pro.
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(session)
        }
        .windowStyle(.volumetric)

        // Espace immersif plein écran pour la visualisation 3D.
        ImmersiveSpace(id: "ImmersiveViewer") {
            ImmersiveViewerView()
                .environmentObject(store)
                .environmentObject(session)
        }
        .immersionStyle(selection: .constant(.full), in: .full)
    }
}
