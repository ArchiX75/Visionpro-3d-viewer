import Foundation

/// Accès au conteneur **iCloud Drive** de l'application.
///
/// Le même conteneur (`iCloud.<bundle-id>`) est utilisable depuis toutes les
/// plateformes Apple (visionOS, iOS, iPadOS, macOS) : les fichiers déposés
/// dans `Documents/` y sont visibles (app Fichiers, Finder, etc.) et
/// synchronisés automatiquement entre appareils.
///
/// NB : nécessite la capability iCloud (iCloud Drive) activée dans Xcode —
/// voir `Visionpro3DViewer.entitlements` et le README.
@MainActor
final class CloudStore: ObservableObject {
    static let shared = CloudStore()

    @Published private(set) var isAvailable = false
    @Published private(set) var files: [CloudFile] = []
    @Published private(set) var statusMessage: String?

    /// Fichier listé dans le conteneur iCloud.
    struct CloudFile: Identifiable, Hashable {
        let id: String // chemin relatif dans le conteneur
        let name: String
        let isDownloaded: Bool
    }

    private init() {
        isAvailable = Self.containerURL != nil
        if isAvailable, let docs = Self.documentsDirectory {
            try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        }
        Task { await refresh() }
    }

    // MARK: - URLs du conteneur

    /// Racine du conteneur ubiquitaire iCloud de l'app (nil si iCloud indisponible).
    static var containerURL: URL? {
        FileManager.default.url(forUbiquityContainerDirectory: nil)
    }

    /// Sous-dossier visible dans iCloud Drive (app Fichiers / Finder).
    static var documentsDirectory: URL? {
        containerURL?.appendingPathComponent("Documents", isDirectory: true)
    }

    static func url(forRelativePath path: String) -> URL? {
        documentsDirectory?.appendingPathComponent(path)
    }

    // MARK: - Listing

    /// Rafraîchit la liste des fichiers 3D présents dans le conteneur iCloud.
    func refresh() async {
        guard let docs = Self.documentsDirectory else { return }
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .ubiquitousItemDownloadingStatusKey, .nameKey]
        guard let enumerator = fm.enumerator(at: docs, includingPropertiesForKeys: keys) else { return }
        var result: [CloudFile] = []
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isDirectory != true,
                  ModelLoader.isSupported(url),
                  let status = values?.ubiquitousItemDownloadingStatus,
                  status != .notDownloaded || (try? fm.startDownloadingUbiquitousItem(at: url)) != nil else { continue }
            let relative = url.path.replacingOccurrences(
                of: docs.path + "/",
                with: ""
            )
            result.append(CloudFile(
                id: relative,
                name: url.lastPathComponent,
                isDownloaded: status == .current
            ))
        }
        files = result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Upload / téléchargement

    /// Copie un fichier local (importé) vers iCloud Drive. Retourne le chemin relatif.
    @discardableResult
    static func uploadToCloud(local url: URL) async throws -> String {
        guard let docs = documentsDirectory else {
            throw CloudError.unavailable
        }
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        let destination = docs.appendingPathComponent(url.lastPathComponent)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: url, to: destination)
        // Rend le fichier ubiquitaire : il est alors synchronisé vers iCloud Drive.
        try FileManager.default.setUbiquitous(true, itemAt: destination, destinationURL: destination)
        return url.lastPathComponent
    }

    /// Garantit qu'un fichier iCloud est téléchargé localement et retourne son URL.
    static func ensureDownloaded(_ relativePath: String) async throws -> URL {
        guard let url = url(forRelativePath: relativePath) else {
            throw CloudError.unavailable
        }
        if (try? url.checkResourceIsReachable()) == true {
            let values = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            if values.ubiquitousItemDownloadingStatus == .current {
                return url
            }
        }
        try FileManager.default.startDownloadingUbiquitousItem(at: url)
        // Attente du téléchargement (avec limite de temps).
        for _ in 0..<60 {
            try await Task.sleep(nanoseconds: 500_000_000)
            let values = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey, .isUbiquitousItemKey])
            if values.ubiquitousItemDownloadingStatus == .current {
                return url
            }
        }
        throw CloudError.downloadTimeout(relativePath)
    }
}

enum CloudError: LocalizedError {
    case unavailable
    case downloadTimeout(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "iCloud Drive n'est pas disponible (connectez-vous à iCloud et activez iCloud Drive)."
        case .downloadTimeout(let name):
            return "Téléchargement iCloud trop long pour \(name)."
        }
    }
}
