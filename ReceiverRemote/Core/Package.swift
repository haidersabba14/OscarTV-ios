// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RemoteInteractionCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "RemoteInteractionCore", targets: ["RemoteInteractionCore"])],
    targets: [
        .target(name: "RemoteInteractionCore"),
        .testTarget(name: "RemoteInteractionCoreTests", dependencies: ["RemoteInteractionCore"])
    ]
)
