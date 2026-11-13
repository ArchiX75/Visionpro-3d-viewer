// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Visionpro-3d-viewer",
    platforms: [
        .visionOS(.v1)
    ],
    products: [
        .executable(
            name: "Visionpro3DViewer",
            targets: ["Visionpro3DViewer"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Visionpro3DViewer",
            path: "Sources/Visionpro3DViewer"
        )
    ]
)
