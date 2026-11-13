import Foundation
import ModelIO
import RealityKit

enum ModelLoaderError: LocalizedError {
    case unsupported(String)
    case empty(String)

    var errorDescription: String? {
        switch self {
        case .unsupported(let name):
            return "Format non pris en charge : \(name)"
        case .empty(let detail):
            return "Fichier 3D illisible ou vide (\(detail))."
        }
    }
}

/// Chargement de fichiers 3D multi-formats vers une `Entity` RealityKit.
///
/// - USD / USDZ / USDA / USDC : chargés nativement par RealityKit
///   (`ModelEntity`), avec matériaux et animations conservés.
/// - OBJ / STL / glTF / GLB / DAE : chargés via ModelIO (`MDLAsset`),
///   puis convertis maillage par maillage en `MeshResource` RealityKit
///   (SceneKit n'étant pas disponible sur visionOS).
enum ModelLoader {
    static let supportedExtensions = ["usdz", "usd", "usda", "usdc", "obj", "stl", "gltf", "glb", "dae"]

    static func isSupported(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    /// Résout le bookmark de sécurité d'une scène persistée et rouvre l'accès au fichier.
    static func resolveBookmark(_ state: SceneState) throws -> URL {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: state.bookmark,
            options: [.withSecurityScope],
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
        default:
            let asset = MDLAsset(url: url)
            guard asset.count > 0 else {
                throw ModelLoaderError.empty(url.lastPathComponent)
            }
            return try entity(from: asset)
        }
    }

    // MARK: - Conversion ModelIO -> RealityKit

    static func entity(from asset: MDLAsset) throws -> Entity {
        let root = Entity()
        for case let object as MDLObject in asset {
            try append(object: object, to: root)
        }
        return root
    }

    private static func append(object: MDLObject, to parent: Entity) throws {
        if let mesh = object as? MDLMesh {
            parent.addChild(try modelEntity(from: mesh))
        }
        for case let child as MDLObject in object.children {
            try append(object: child, to: parent)
        }
    }

    private static func modelEntity(from mesh: MDLMesh) throws -> ModelEntity {
        let vertexCount = mesh.vertexCount

        guard let positions = float3Array(from: mesh, attribute: MDLVertexAttributePosition, count: vertexCount) else {
            throw ModelLoaderError.empty("maillage sans positions")
        }

        var descriptor = MeshDescriptor()
        descriptor.positions = .init(positions)

        if let normals = float3Array(from: mesh, attribute: MDLVertexAttributeNormal, count: vertexCount) {
            descriptor.normals = .init(normals)
        }
        if let uvs = float2Array(from: mesh, attribute: MDLVertexAttributeTextureCoordinate, count: vertexCount) {
            descriptor.textureCoordinates = .init(uvs)
        }

        let indices = triangleIndices(from: mesh)
        guard !indices.isEmpty else {
            throw ModelLoaderError.empty("maillage sans faces")
        }
        descriptor.primitives = .triangles(indices)

        // NB : selon la version du SDK, la signature peut exiger un second
        // paramètre `materials: []`.
        let resource = try MeshResource.generate(from: [descriptor])
        let material = SimpleMaterial(color: .lightGray, roughness: 0.6, isMetallic: false)
        return ModelEntity(mesh: resource, materials: [material])
    }

    // MARK: - Extraction des buffers ModelIO

    /// Retourne le buffer vertex à l'index donné (énumération rapide, compatible
    /// avec `MDLVertexBufferMap` qui n'est pas un NSArray).
    private static func vertexBuffer(_ mesh: MDLMesh, at index: Int) -> MDLVertexBuffer? {
        var current = 0
        for case let buffer as MDLVertexBuffer in mesh.vertexBuffers {
            if current == index { return buffer }
            current += 1
        }
        return nil
    }

    private static func float3Array(from mesh: MDLMesh, attribute: String, count: Int) -> [SIMD3<Float>]? {
        guard let attr = mesh.vertexDescriptor.attributes.first(where: { $0.name == attribute }),
              let buffer = vertexBuffer(mesh, at: attr.bufferIndex) else { return nil }
        let stride = max(buffer.stride, MemoryLayout<SIMD3<Float>>.stride)
        let base = buffer.data.advanced(by: attr.offset)
        var result = [SIMD3<Float>]()
        result.reserveCapacity(count)
        for i in 0..<count {
            result.append(base.advanced(by: i * stride).load(as: SIMD3<Float>.self))
        }
        return result
    }

    private static func float2Array(from mesh: MDLMesh, attribute: String, count: Int) -> [SIMD2<Float>]? {
        guard let attr = mesh.vertexDescriptor.attributes.first(where: { $0.name == attribute }),
              let buffer = vertexBuffer(mesh, at: attr.bufferIndex) else { return nil }
        let stride = max(buffer.stride, MemoryLayout<SIMD2<Float>>.stride)
        let base = buffer.data.advanced(by: attr.offset)
        var result = [SIMD2<Float>]()
        result.reserveCapacity(count)
        for i in 0..<count {
            result.append(base.advanced(by: i * stride).load(as: SIMD2<Float>.self))
        }
        return result
    }

    private static func triangleIndices(from mesh: MDLMesh) -> [UInt32] {
        var indices = [UInt32]()
        for case let submesh as MDLSubmesh in mesh.submeshes {
            let base = submesh.indexBuffer.data
            let count = submesh.indexCount
            switch submesh.indexType {
            case .uInt32:
                for i in 0..<count {
                    indices.append(base.load(fromByteOffset: i * MemoryLayout<UInt32>.size, as: UInt32.self))
                }
            case .uInt16:
                for i in 0..<count {
                    indices.append(UInt32(base.load(fromByteOffset: i * MemoryLayout<UInt16>.size, as: UInt16.self)))
                }
            case .uInt8:
                for i in 0..<count {
                    indices.append(UInt32(base.load(fromByteOffset: i * MemoryLayout<UInt8>.size, as: UInt8.self)))
                }
            @unknown default:
                break
            }
        }
        return indices
    }
}
