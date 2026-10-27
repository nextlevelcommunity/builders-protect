// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CVEBuilder",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CVEBuilder", targets: ["CVEBuilder"]),
        .library(name: "CVECore", targets: ["CVECore"])
    ],
    targets: [
        .target(
            name: "CVECore",
            path: "Sources/CVECore",
            resources: [.copy("Resources/PestKnowledge.json")]
        ),
        .executableTarget(
            name: "CVEBuilder",
            dependencies: ["CVECore"],
            path: "Sources/CVEBuilder",
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "CVECoreTests",
            dependencies: ["CVECore"],
            path: "Tests/CVECoreTests"
        )
    ]
)
