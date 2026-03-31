// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DRay",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DRay", targets: ["DRay"]),
        .executable(name: "DRayMenuBarHelper", targets: ["DRayMenuBarHelper"])
    ],
    targets: [
        .executableTarget(
            name: "DRay",
            path: "DRay"
        ),
        .executableTarget(
            name: "DRayMenuBarHelper",
            path: "DRayMenuBarHelper"
        )
    ]
)
