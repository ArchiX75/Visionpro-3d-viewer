import SwiftUI
import UniformTypeIdentifiers

/// Écran d'accueil : grille de cartes des scènes enregistrées ( rouvertes telles
/// quelles) + section iCloud Drive, et bouton d'import d'un nouveau fichier 3D.
struct ContentView: View {
    @EnvironmentObject private var store: SceneStateStore
    @EnvironmentObject private var session: ViewerSession
    @StateObject private var cloud = CloudStore.shared
    @State private var path: [SceneState] = []
    @State private var isImporting = false
    @State private var errorMessage: String?

    private let contentTypes: [UTType] = ModelLoader.supportedExtensions
        .compactMap { UTType(filenameExtension: $0) }

    private let columns = [GridItem(.adaptive(minimum: 240, maximum: 320), spacing: 20)]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    // MARK: Scènes enregistrées (grille de cartes)
                    SectionHeader(title: "Scènes enregistrées", systemImage: "cube")
                    if store.states.isEmpty {
                        ContentUnavailableView(
                            "Aucune scène",
                            systemImage: "cube.transparent",
                            description: Text("Ouvrez un fichier 3D pour commencer.")
                        )
                        .frame(maxWidth: .infinity)
                    } else {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(store.states) { state in
                                NavigationLink(value: state) {
                                    SceneCard(state: state)
                                }
                                .contextMenu {
                                    if state.cloudPath == nil {
                                        Button("Copier vers iCloud Drive", systemImage: "icloud.and.arrow.up") {
                                            Task { await copyToCloud(state) }
                                        }
                                    }
                                    Button("Supprimer", systemImage: "trash", role: .destructive) {
                                        if let index = store.states.firstIndex(where: { $0.id == state.id }) {
                                            store.remove(at: IndexSet(integer: index))
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // MARK: Fichiers iCloud Drive (synchronisés entre appareils)
                    SectionHeader(title: "iCloud Drive", systemImage: "icloud")
                    if !cloud.isAvailable {
                        Text("iCloud indisponible : connectez-vous à iCloud et activez iCloud Drive dans les réglages.")
                            .foregroundStyle(.secondary)
                    } else if cloud.files.isEmpty {
                        Text("Aucun fichier 3D dans iCloud Drive pour le moment.")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(cloud.files) { file in
                                Button {
                                    openCloudFile(file)
                                } label: {
                                    Label(file.name, systemImage: file.isDownloaded ? "icloud.fill" : "icloud.and.arrow.down")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                .padding(24)
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
                isPresented: .constant(errorMessage != nil),
                actions: { Button("OK") { errorMessage = nil } },
                message: { Text(errorMessage ?? "") }
            )
            .navigationDestination(for: SceneState.self) { state in
                ViewerSceneView(state: state)
            }
            .background(BackgroundView())
        }
    }

    // MARK: - Actions

    private func importFile(_ result: Result<URL, Error>) async {
        switch result {
        case .failure(let error):
            await MainActor.run { errorMessage = error.localizedDescription }
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                await MainActor.run { errorMessage = "Accès au fichier refusé." }
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
            }
            await cloud.refresh()
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func openCloudFile(_ file: CloudStore.CloudFile) {
        let state = SceneState(cloudPath: file.id, fileName: file.name)
        store.add(state)
        path.append(state)
    }
}

// MARK: - Sous-vues d'interface

private struct SectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Theme.accent, in: .circle)
            Text(title)
                .font(.title3.bold())
        }
    }
}

/// Carte de scène : nom du fichier, niveau de zoom mémorisé, origine (local/iCloud).
private struct SceneCard: View {
    let state: SceneState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: state.cloudPath != nil ? "icloud.fill" : "cube.fill")
                .font(.system(size: 36))
                .foregroundStyle(.white)
                .frame(width: 76, height: 76)
                .background(Theme.accent, in: .circle)
            Text(state.fileName)
                .font(.headline)
                .lineLimit(1)
            HStack(spacing: 8) {
                Label("zoom \(Int(state.scale * 100)) %", systemImage: "magnifyingglass")
                if state.cloudPath != nil {
                    Label("iCloud", systemImage: "icloud")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Theme.accent.opacity(0.45), lineWidth: 1.5)
        )
    }
}
