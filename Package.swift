// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenGuest",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "OpenGuest", targets: ["OpenGuest"])],
    targets: [
        .target(name: "OpenGuestCore"),
        .executableTarget(name: "OpenGuest", dependencies: ["OpenGuestCore"]),
        .testTarget(name: "OpenGuestCoreTests", dependencies: ["OpenGuestCore"])
    ]
)
