// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LiveTranscribe",
    platforms: [.macOS("14.2")],
    products: [.executable(name: "LiveTranscribe", targets: ["LiveTranscribe"])],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.15.3"),
    ],
    targets: [
        .executableTarget(
            name: "LiveTranscribe",
            dependencies: [.product(name: "FluidAudio", package: "FluidAudio")]
        ),
        .testTarget(name: "LiveTranscribeTests", dependencies: ["LiveTranscribe"]),
    ]
)
