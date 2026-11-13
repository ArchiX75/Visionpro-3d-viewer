import Foundation

/// Gestionnaire observable de la liste des scènes enregistrées.
/// Chaque scène est persistée individuellement en JSON dans
/// `Documents/Scenes/<id>.json`.
@MainActor
final class SceneStateStore: ObservableObject {
    @Published private(set) var states: [SceneState] = []

    private let directory: URL

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        directory = documents.appendingPathComponent("Scenes", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        load()
    }

    /// Recharge toutes les scènes persistées depuis le disque.
    func load() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return }
        states = files
            .filter { $0.pathExtension.lowercased() == "json" }
            .compactMap { try? JSONDecoder().decode(SceneState.self, from: Data(contentsOf: $0)) }
            .sorted { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }
    }

    /// Ajoute une nouvelle scène (fichier nouvellement importé).
    func add(_ state: SceneState) {
        states.append(state)
        states.sort { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }
        persist(state)
    }

    /// Met à jour l'état (transformée) d'une scène existante et le persiste.
    func update(_ state: SceneState) {
        guard let index = states.firstIndex(where: { $0.id == state.id }) else { return }
        states[index] = state
        persist(state)
    }

    /// Supprime des scènes (et leurs fichiers de persistance).
    func remove(at offsets: IndexSet) {
        for index in offsets {
            let state = states[index]
            try? FileManager.default.removeItem(at: fileURL(for: state))
            states.remove(at: index)
        }
    }

    private func persist(_ state: SceneState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: fileURL(for: state))
    }

    private func fileURL(for state: SceneState) -> URL {
        directory.appendingPathComponent("\(state.id.uuidString).json")
    }
}
