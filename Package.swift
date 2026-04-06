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
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "0.7.0")
    ],
    targets: [
        .executableTarget(
            name: "DRay",
            path: "DRay"
        ),
        .executableTarget(
            name: "DRayMenuBarHelper",
            path: "DRayMenuBarHelper"
        ),
        .testTarget(
            name: "DRayTests",
            dependencies: [
                "DRay",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests"
        )
    ]
)
