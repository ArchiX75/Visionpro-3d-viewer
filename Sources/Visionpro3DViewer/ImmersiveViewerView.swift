import SwiftUI

/// Espace immersif plein écran : la scène 3D occupe tout le champ de vision.
struct ImmersiveViewerView: View {
    @EnvironmentObject private var store: SceneStateStore
    @EnvironmentObject private var session: ViewerSession
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        if let state = session.current {
            InteractiveModelView(state: state) { updated in
                store.update(updated)
                session.current = updated
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    Task { await dismissImmersiveSpace() }
                } label: {
                    Label("Quitter l'immersion", systemImage: "xmark.circle.fill")
                }
                .buttonStyle(.bordered)
                .padding()
            }
        } else {
            ContentUnavailableView(
                "Aucune scène",
                systemImage: "visionpro.slash",
                description: Text("Ouvrez une scène depuis la fenêtre principale.")
            )
        }
    }
}
