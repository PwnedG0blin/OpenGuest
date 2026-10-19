// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Stratovo",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Stratovo", targets: ["Stratovo"])],
    targets: [
        .target(name: "StratovoCore", resources: [.process("Resources")]),
        .executableTarget(name: "Stratovo", dependencies: ["StratovoCore"]),
        .testTarget(name: "StratovoCoreTests", dependencies: ["StratovoCore"]),
        .testTarget(name: "PlayerIntegrationTests", dependencies: ["Stratovo", "StratovoCore"])
    ]
)
