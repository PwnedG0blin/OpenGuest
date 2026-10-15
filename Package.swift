// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Pixelkoje",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Pixelkoje", targets: ["OpenGuest"])],
    targets: [
        .target(name: "OpenGuestCore"),
        .executableTarget(name: "OpenGuest", dependencies: ["OpenGuestCore"]),
        .testTarget(name: "OpenGuestCoreTests", dependencies: ["OpenGuestCore"])
    ]
)
