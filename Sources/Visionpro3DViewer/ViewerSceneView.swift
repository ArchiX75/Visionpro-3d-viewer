import RealityKit
import SwiftUI

/// Vue de visualisation d'une scène 3D :
/// - chargement du fichier (multi-formats) ;
/// - manipulation par gestes : zoom (pincement), déplacement (drag), rotation ;
/// - restauration de l'état exact laissé par l'utilisateur (zoom, position, rotation) ;
/// - persistance automatique de cet état à chaque fin de geste et à la fermeture.
struct ViewerSceneView: View {
    let state: SceneState
    let onStateChange: (SceneState) -> Void

    @State private var root: Entity?
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
                    .background(.red.opacity(0.8), in: .rect(cornerRadius: 12))
                    .padding()
            }
        }
        .overlay(alignment: .bottom) {
            Text("\(state.fileName) — zoom \(Int(scale * 100)) %")
                .font(.caption)
                .padding(8)
                .background(.thinMaterial, in: .capsule)
                .padding(.bottom, 12)
        }
        .onDisappear { persist() }
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

    // MARK: - Chargement et persistance

    private func loadModel() async {
        do {
            let url = try await ModelLoader.resolveURL(for: state)
            let entity = try await ModelLoader.loadEntity(from: url)
            await MainActor.run { root = entity }
        } catch {
            await MainActor.run { loadError = error.localizedDescription }
        }
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
