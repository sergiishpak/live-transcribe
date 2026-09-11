// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LiveTranscribe",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "LiveTranscribe", targets: ["LiveTranscribe"])],
    targets: [
        .executableTarget(name: "LiveTranscribe"),
        .testTarget(name: "LiveTranscribeTests", dependencies: ["LiveTranscribe"]),
    ]
)
