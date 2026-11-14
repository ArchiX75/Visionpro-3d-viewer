import Foundation
import RealityKit
import simd

enum ModelLoaderError: LocalizedError {
    case unsupported(String)
    case empty(String)

    var errorDescription: String? {
        switch self {
        case .unsupported(let name):
            return "Format non pris en charge sur visionOS : \(name)"
        case .empty(let detail):
            return "Fichier 3D illisible ou vide (\(detail))."
        }
    }
}

/// Chargement de fichiers 3D vers une `Entity` RealityKit.
///
/// - USD / USDZ / USDA / USDC : chargés nativement par RealityKit
///   (`ModelEntity`), avec matériaux et animations conservés.
/// - OBJ / STL : parsés directement (ModelIO et SceneKit n'étant pas
///   disponibles sur visionOS), puis convertis en `MeshResource` RealityKit.
enum ModelLoader {
    static let supportedExtensions = ["usdz", "usd", "usda", "usdc", "obj", "stl"]

    static func isSupported(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    /// Résout l'URL du fichier d'une scène : iCloud Drive si `cloudPath` est
    /// renseigné (avec téléchargement à la demande), sinon bookmark local.
    static func resolveURL(for state: SceneState) async throws -> URL {
        if let cloudPath = state.cloudPath {
            return try await CloudStore.ensureDownloaded(cloudPath)
        }
        return try resolveBookmark(state)
    }

    /// Résout le bookmark d'une scène persistée et rouvre l'accès au fichier.
    static func resolveBookmark(_ state: SceneState) throws -> URL {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: state.bookmark,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        // L'accès reste ouvert pendant la durée de vie de l'app.
        _ = url.startAccessingSecurityScopedResource()
        return url
    }

    /// Charge un fichier 3D en entité RealityKit racine.
    static func loadEntity(from url: URL) async throws -> Entity {
        guard isSupported(url) else {
            throw ModelLoaderError.unsupported(url.pathExtension)
        }
        switch url.pathExtension.lowercased() {
        case "usdz", "usd", "usda", "usdc":
            return try await ModelEntity.load(contentsOf: url)
        case "obj":
            return try meshEntity(from: OBJParser.parse(url: url))
        case "stl":
            return try meshEntity(from: STLParser.parse(url: url))
        default:
            throw ModelLoaderError.unsupported(url.pathExtension)
        }
    }

    // MARK: - Construction RealityKit

    private static func meshEntity(from mesh: ParsedMesh) throws -> ModelEntity {
        guard !mesh.positions.isEmpty else {
            throw ModelLoaderError.empty("maillage sans positions")
        }
        guard !mesh.indices.isEmpty else {
            throw ModelLoaderError.empty("maillage sans faces")
        }
        let normals = mesh.normals.isEmpty
            ? ParsedMesh.computeNormals(positions: mesh.positions, indices: mesh.indices)
            : mesh.normals
        var descriptor = MeshDescriptor()
        descriptor.positions = .init(mesh.positions)
        descriptor.normals = .init(normals)
        descriptor.primitives = .triangles(mesh.indices)
        let resource = try MeshResource.generate(from: [descriptor])
        let material = SimpleMaterial(color: .lightGray, roughness: 0.6, isMetallic: false)
        return ModelEntity(mesh: resource, materials: [material])
    }
}

/// Maillage intermédiaire parsé depuis un fichier OBJ ou STL.
struct ParsedMesh {
    var positions: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    var indices: [UInt32] = []

    /// Normales lissées par sommet, calculées à partir des faces.
    static func computeNormals(positions: [SIMD3<Float>], indices: [UInt32]) -> [SIMD3<Float>] {
        var normals = [SIMD3<Float>](repeating: .zero, count: positions.count)
        var t = 0
        while t + 2 < indices.count {
            let a = positions[Int(indices[t])]
            let b = positions[Int(indices[t + 1])]
            let c = positions[Int(indices[t + 2])]
            let n = simd_cross(b - a, c - a)
            normals[Int(indices[t])] += n
            normals[Int(indices[t + 1])] += n
            normals[Int(indices[t + 2])] += n
            t += 3
        }
        return normals.map { v in
            let len = simd_length(v)
            return len > 0 ? v / len : SIMD3<Float>(0, 1, 0)
        }
    }
}

/// Parseur OBJ (ASCII) : sommets `v`, faces `f` (indices 1-based, négatifs relatifs).
enum OBJParser {
    static func parse(url: URL) throws -> ParsedMesh {
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else {
            throw ModelLoaderError.empty("OBJ non décodable en UTF-8")
        }
        var mesh = ParsedMesh()
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let tokens = rawLine.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard let keyword = tokens.first else { continue }
            switch keyword {
            case "v":
                guard tokens.count >= 4,
                      let x = Float(tokens[1]), let y = Float(tokens[2]), let z = Float(tokens[3]) else { continue }
                mesh.positions.append(SIMD3<Float>(x, y, z))
            case "f":
                var face: [Int] = []
                for token in tokens.dropFirst() {
                    guard let indexPart = token.split(separator: "/").first,
                          let index = Int(indexPart) else { continue }
                    let resolved = index < 0 ? mesh.positions.count + index : index - 1
                    guard resolved >= 0, resolved < mesh.positions.count else { continue }
                    face.append(resolved)
                }
                guard face.count >= 3 else { continue }
                for k in 1..<face.count - 1 {
                    mesh.indices.append(UInt32(truncatingIfNeeded: face[0]))
                    mesh.indices.append(UInt32(truncatingIfNeeded: face[k]))
                    mesh.indices.append(UInt32(truncatingIfNeeded: face[k + 1]))
                }
            default:
                break
            }
        }
        return mesh
    }
}

/// Parseur STL (binaire ou ASCII).
enum STLParser {
    static func parse(url: URL) throws -> ParsedMesh {
        let data = try Data(contentsOf: url)
        if isBinary(data: data) {
            return try parseBinary(data)
        }
        return try parseASCII(data)
    }

    private static func isBinary(data: Data) -> Bool {
        guard data.count >= 84 else { return false }
        let count = Int(u32LE(data, 80))
        return count > 0 && 84 + count * 50 == data.count
    }

    private static func parseBinary(_ data: Data) throws -> ParsedMesh {
        var mesh = ParsedMesh()
        let count = Int(u32LE(data, 80))
        mesh.positions.reserveCapacity(count * 3)
        for i in 0..<count {
            let base = 84 + i * 50
            let n = SIMD3<Float>(f32LE(data, base), f32LE(data, base + 4), f32LE(data, base + 8))
            for k in 0..<3 {
                let o = base + 12 + k * 12
                mesh.positions.append(SIMD3<Float>(f32LE(data, o), f32LE(data, o + 4), f32LE(data, o + 8)))
                mesh.normals.append(n)
            }
            let first = UInt32(truncatingIfNeeded: i * 3)
            mesh.indices.append(contentsOf: [first, first + 1, first + 2])
        }
        guard !mesh.indices.isEmpty else {
            throw ModelLoaderError.empty("STL binaire sans facettes")
        }
        return mesh
    }

    private static func parseASCII(_ data: Data) throws -> ParsedMesh {
        guard let text = String(data: data, encoding: .utf8) else {
            throw ModelLoaderError.empty("STL non décodable en UTF-8")
        }
        var mesh = ParsedMesh()
        var facetNormal = SIMD3<Float>(0, 1, 0)
        var vertices: [SIMD3<Float>] = []
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let tokens = rawLine.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard let keyword = tokens.first else { continue }
            switch keyword {
            case "facet":
                guard tokens.count >= 5,
                      let x = Float(tokens[2]), let y = Float(tokens[3]), let z = Float(tokens[4]) else { continue }
                facetNormal = SIMD3<Float>(x, y, z)
            case "vertex":
                guard tokens.count >= 4,
                      let x = Float(tokens[1]), let y = Float(tokens[2]), let z = Float(tokens[3]) else { continue }
                vertices.append(SIMD3<Float>(x, y, z))
                if vertices.count == 3 {
                    let first = UInt32(truncatingIfNeeded: mesh.positions.count)
                    mesh.positions.append(contentsOf: vertices)
                    mesh.normals.append(contentsOf: [facetNormal, facetNormal, facetNormal])
                    mesh.indices.append(contentsOf: [first, first + 1, first + 2])
                    vertices.removeAll(keepingCapacity: true)
                }
            default:
                break
            }
        }
        guard !mesh.indices.isEmpty else {
            throw ModelLoaderError.empty("STL ASCII sans facettes")
        }
        return mesh
    }

    private static func u32LE(_ data: Data, _ offset: Int) -> UInt32 {
        let bytes = data.subdata(in: offset..<offset + 4)
        return UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
    }

    private static func f32LE(_ data: Data, _ offset: Int) -> Float {
        Float(bitPattern: u32LE(data, offset))
    }
}
