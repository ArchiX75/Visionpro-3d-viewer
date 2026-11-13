import Foundation

/// Session de visualisation partagée entre la fenêtre principale et l'espace immersif.
@MainActor
final class ViewerSession: ObservableObject {
    /// Scène actuellement affichée (mise à jour à chaque modification de l'état).
    @Published var current: SceneState?
}
