import Foundation

/// État complet d'une scène 3D : le fichier ouvert plus la transformée
/// (position, rotation, échelle) telle que l'utilisateur l'a laissée.
///
/// La scène est persistée en JSON dans le dossier Documents de l'app afin
/// d'être restaurée à l'identique lors d'une réouverture ultérieure.
struct SceneState: Codable, Identifiable, Hashable {
    let id: UUID
    var fileName: String
    /// Bookmark de sécurité permettant de rouvrir le fichier local ultérieurement.
    var bookmark: Data
    /// Chemin relatif du fichier dans le conteneur iCloud Drive (si la scène
    /// provient d'iCloud ; nil pour un fichier local importé).
    var cloudPath: String?
    /// Position de l'entité dans la scène, en mètres (x, y, z).
    var position: [Double]
    /// Rotation de l'entité sous forme de quaternion (x, y, z, w).
    var rotation: [Double]
    /// Facteur de zoom (échelle uniforme).
    var scale: Double

    init(
        id: UUID = UUID(),
        url: URL,
        position: [Double] = [0, 0, 0],
        rotation: [Double] = [0, 0, 0, 1],
        scale: Double = 1.0
    ) {
        self.id = id
        self.fileName = url.lastPathComponent
        // Le bookmark inclut le security scope : le fichier restera accessible
        // même après la fermeture de l'app.
        self.bookmark = (try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )) ?? Data()
        self.cloudPath = nil
        self.position = position
        self.rotation = rotation
        self.scale = scale
    }

    /// Scène pointant vers un fichier stocké dans iCloud Drive.
    init(cloudPath: String, fileName: String) {
        self.id = UUID()
        self.fileName = fileName
        self.bookmark = Data()
        self.cloudPath = cloudPath
        self.position = [0, 0, 0]
        self.rotation = [0, 0, 0, 1]
        self.scale = 1.0
    }
}
