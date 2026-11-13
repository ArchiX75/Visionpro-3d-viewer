import RealityKit
import SwiftUI

/// Composant 3D interactif réutilisable (fenêtre volumétrique ET espace immersif) :
/// - chargement du fichier (multi-formats, local ou iCloud) avec état de progression ;
/// - gestes : zoom (pincement), déplacement (drag), rotation, double tap pour réinitialiser ;
/// - HUD : niveau de zoom + boutons réinitialiser / centrer ;
/// - restauration de l'état laissé par l'utilisateur et persistance automatique.
struct InteractiveModelView: View {
    let state: SceneState
    let onStateChange: (SceneState) -> Void

    @State private var root: Entity?
    @State private var isLoading = true
    @State private var position: SIMD3<Float>
    @State private var rotation: simd_quatf
    @State private var scale: Float
    @State private var loadError: String?

    // Valeurs de référence capturées au début de chaque geste.
    @State private var basePosition: SIMD3<Float> = .zero
    @State private var baseScale: Float = 1
    @State private var baseRotation: simd_quatf = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))

    private let minScale: Float = 0.05
    private let maxScale: Float = 50

    init(state: SceneState, onStateChange: @escaping (SceneState) -> Void) {
        self.state = state
        self.onStateChange = onStateChange
        let p = state.position
        let r = state.rotation
        _position = State(initialValue: SIMD3<Float>(Float(p[0]), Float(p[1]), Float(p[2])))
        _rotation = State(initialValue: simd_quatf(vector: SIMD4<Float>(Float(r[0]), Float(r[1]), Float(r[2]), Float(r[3]))))
        _scale = State(initialValue: Float(state.scale))
    }

    var body: some View {
        RealityView { content in
            Task { await loadModel() }
            if let root {
                content.add(root)
            }
        } update: { _ in
            guard let root else { return }
            root.transform.translation = position
            root.transform.rotation = rotation
            root.transform.scale = SIMD3<Float>(repeating: scale)
        }
        .gesture(manipulationGestures)
        .onTapGesture(count: 2) { resetTransform() }
        .overlay(alignment: .top) {
            if let loadError {
                Text(loadError)
                    .padding()
                    .background(.red.opacity(0.85), in: .rect(cornerRadius: 12))
                    .padding()
            } else if isLoading {
                ProgressView("Chargement de \(state.fileName)…")
                    .padding()
                    .background(.thinMaterial, in: .rect(cornerRadius: 12))
                    .padding()
            }
        }
        .overlay(alignment: .bottom) {
            hud
        }
        .onDisappear { persist() }
    }

    // MARK: - HUD

    private var hud: some View {
        HStack(spacing: 16) {
            Button {
                resetTransform()
            } label: {
                Label("Réinitialiser", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.borderedProminent)
            Button {
                fitToFrame()
            } label: {
                Label("Centrer", systemImage: "scope")
            }
            .buttonStyle(.borderedProminent)
            Text("zoom \(Int(scale * 100)) %")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: .capsule)
        .overlay(
            Capsule()
                .stroke(Theme.accent.opacity(0.5), lineWidth: 1.5)
        )
        .padding(.bottom, 16)
    }

    // MARK: - Gestes de manipulation

    private var manipulationGestures: some Gesture {
        SimultaneousGesture(
            SimultaneousGesture(
                // Zoom (pincement à deux doigts)
                MagnificationGesture()
                    .onChanged { value in
                        scale = min(max(baseScale * Float(value), minScale), maxScale)
                    }
                    .onEnded { _ in
                        baseScale = scale
                        persist()
                    },
                // Déplacement (drag)
                DragGesture()
                    .onChanged { value in
                        position = basePosition + SIMD3<Float>(
                            Float(value.translation.width) * 0.001,
                            Float(-value.translation.height) * 0.001,
                            0
                        )
                    }
                    .onEnded { _ in
                        basePosition = position
                        persist()
                    }
            ),
            // Rotation (rotation à deux doigts autour de l'axe vertical)
            RotationGesture()
                .onChanged { value in
                    rotation = simd_quatf(angle: Float(value), axis: SIMD3<Float>(0, 1, 0)) * baseRotation
                }
                .onEnded { _ in
                    baseRotation = rotation
                    persist()
                }
        )
    }

    // MARK: - Chargement, recadrage et persistance

    private func loadModel() async {
        do {
            let url = try await ModelLoader.resolveURL(for: state)
            let entity = try await ModelLoader.loadEntity(from: url)
            await MainActor.run {
                root = entity
                isLoading = false
            }
        } catch {
            await MainActor.run {
                loadError = error.localizedDescription
                isLoading = false
            }
        }
    }

    /// Recadre le modèle dans la vue selon sa bounding box.
    private func fitToFrame() {
        guard let root else { return }
        let box = root.visualBounds(relativeTo: root)
        let extents = box.extents
        let maxDim = max(extents.x, extents.y, extents.z)
        guard maxDim > 0 else { return }
        scale = min(max(0.8 / maxDim, minScale), maxScale)
        position = -SIMD3<Float>(box.center)
        baseScale = scale
        basePosition = position
        persist()
    }

    private func resetTransform() {
        position = .zero
        rotation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        scale = 1
        basePosition = .zero
        baseScale = 1
        baseRotation = rotation
        persist()
    }

    /// Enregistre l'état courant de la scène (pour rouvrir la scène telle quelle).
    private func persist() {
        var updated = state
        updated.position = [Double(position.x), Double(position.y), Double(position.z)]
        let q = rotation.vector
        updated.rotation = [Double(q.x), Double(q.y), Double(q.z), Double(q.w)]
        updated.scale = Double(scale)
        onStateChange(updated)
    }
}

/// Vue de la scène dans la fenêtre principale : modèle interactif + bouton d'immersion.
struct ViewerSceneView: View {
    let state: SceneState

    @EnvironmentObject private var store: SceneStateStore
    @EnvironmentObject private var session: ViewerSession
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace

    var body: some View {
        InteractiveModelView(state: state) { updated in
            store.update(updated)
            session.current = updated
        }
        .navigationTitle(state.fileName)
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button {
                    Task {
                        session.current = state
                        _ = await openImmersiveSpace(id: "ImmersiveViewer")
                    }
                } label: {
                    Label("Mode immersif", systemImage: "visionpro")
                }
            }
        }
    }
}
