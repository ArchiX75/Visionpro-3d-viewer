import SwiftUI
import UniformTypeIdentifiers

/// Écran d'accueil : liste des scènes enregistrées (rouvertes telles quelles)
/// et bouton d'import d'un nouveau fichier 3D.
struct ContentView: View {
    @StateObject private var store = SceneStateStore()
    @State private var path: [SceneState] = []
    @State private var isImporting = false
    @State private var importError: String?

    private let contentTypes: [UTType] = ModelLoader.supportedExtensions
        .compactMap { UTType(filenameExtension: $0) }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if store.states.isEmpty {
                    ContentUnavailableView(
                        "Aucune scène",
                        systemImage: "cube.transparent",
                        description: Text("Ouvrez un fichier 3D pour commencer.")
                    )
                }
                ForEach(store.states) { state in
                    NavigationLink(value: state) {
                        Label {
                            Text(state.fileName)
                        } icon: {
                            Image(systemName: "cube")
                        }
                        .badge(Text("zoom \(Int(state.scale * 100)) %"))
                    }
                }
                .onDelete(perform: store.remove)
            }
            .navigationTitle("Vision Pro 3D Viewer")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isImporting = true
                    } label: {
                        Label("Ouvrir un fichier 3D", systemImage: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: contentTypes
            ) { result in
                Task { await importFile(result) }
            }
            .alert(
                "Erreur d'import",
                isPresented: .constant(importError != nil),
                actions: { Button("OK") { importError = nil } },
                message: { Text(importError ?? "") }
            )
            .navigationDestination(for: SceneState.self) { state in
                ViewerSceneView(state: state) { updated in
                    store.update(updated)
                }
            }
        }
    }

    private func importFile(_ result: Result<URL, Error>) async {
        switch result {
        case .failure(let error):
            await MainActor.run { importError = error.localizedDescription }
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                await MainActor.run { importError = "Accès au fichier refusé." }
                return
            }
            // Le bookmark (avec security scope) est créé tant que l'accès est actif.
            let state = SceneState(url: url)
            url.stopAccessingSecurityScopedResource()
            await MainActor.run {
                store.add(state)
                path.append(state) // ouvre directement la scène importée
            }
        }
    }
}
