import SwiftUI
import UniformTypeIdentifiers

/// Écran d'accueil : scènes enregistrées localement + fichiers iCloud Drive,
/// et bouton d'import d'un nouveau fichier 3D.
struct ContentView: View {
    @StateObject private var store = SceneStateStore()
    @StateObject private var cloud = CloudStore.shared
    @State private var path: [SceneState] = []
    @State private var isImporting = false
    @State private var importError: String?
    @State private var cloudError: String?

    private let contentTypes: [UTType] = ModelLoader.supportedExtensions
        .compactMap { UTType(filenameExtension: $0) }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                // MARK: Scènes enregistrées (état restauré tel quel)
                Section("Scènes enregistrées") {
                    if store.states.isEmpty {
                        ContentUnavailableView(
                            "Aucune scène",
                            systemImage: "cube.transparent",
                            description: Text("Ouvrez un fichier 3D pour commencer.")
                        )
                    }
                    ForEach(store.states) { state in
                        NavigationLink(value: state) {
                            Label(state.fileName, systemImage: state.cloudPath != nil ? "icloud" : "cube")
                                .badge(Text("zoom \(Int(state.scale * 100)) %"))
                        }
                        .contextMenu {
                            if state.cloudPath == nil {
                                Button("Copier vers iCloud Drive") {
                                    Task { await copyToCloud(state) }
                                }
                            }
                        }
                    }
                    .onDelete(perform: store.remove)
                }

                // MARK: Fichiers iCloud Drive (synchronisés entre appareils)
                if cloud.isAvailable {
                    Section("iCloud Drive") {
                        if cloud.files.isEmpty {
                            Text("Aucun fichier 3D dans iCloud Drive pour le moment.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(cloud.files) { file in
                            Button {
                                openCloudFile(file)
                            } label: {
                                Label(file.name, systemImage: file.isDownloaded ? "icloud.fill" : "icloud.and.arrow.down")
                            }
                        }
                    }
                } else {
                    Section("iCloud Drive") {
                        Text("iCloud indisponible : connectez-vous à iCloud et activez iCloud Drive dans les réglages.")
                            .foregroundStyle(.secondary)
                    }
                }
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
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        Task { await cloud.refresh() }
                    } label: {
                        Label("Rafraîchir iCloud", systemImage: "arrow.clockwise.icloud")
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
                "Erreur",
                isPresented: .constant(importError != nil || cloudError != nil),
                actions: { Button("OK") { importError = nil; cloudError = nil } },
                message: { Text(importError ?? cloudError ?? "") }
            )
            .navigationDestination(for: SceneState.self) { state in
                ViewerSceneView(state: state) { updated in
                    store.update(updated)
                }
            }
        }
    }

    // MARK: - Actions

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

    private func copyToCloud(_ state: SceneState) async {
        do {
            let url = try ModelLoader.resolveBookmark(state)
            let relative = try await CloudStore.uploadToCloud(local: url)
            await MainActor.run {
                var updated = state
                updated.cloudPath = relative
                store.update(updated)
                cloud.refresh()
            }
        } catch {
            await MainActor.run { cloudError = error.localizedDescription }
        }
    }

    private func openCloudFile(_ file: CloudStore.CloudFile) {
        let state = SceneState(cloudPath: file.id, fileName: file.name)
        store.add(state)
        path.append(state)
    }
}
