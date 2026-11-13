import SwiftUI

/// Point d'entrée de l'application (100 % Swift / SwiftUI, cible visionOS).
@main
struct Visionpro3DViewerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Fenêtre volumétrique : plus adaptée à la visualisation 3D sur Vision Pro.
        .windowStyle(.volumetric)
    }
}
