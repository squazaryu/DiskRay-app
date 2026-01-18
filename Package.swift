// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DRay",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DRay", targets: ["DRay"])
    ],
    targets: [
        .executableTarget(
            name: "DRay",
            path: "DRay"
        )
    ]
)
