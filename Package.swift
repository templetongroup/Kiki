// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Kiki",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "Vendor/whisper.cpp"),
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.15.5")
    ],
    targets: [
        .executableTarget(
            name: "Kiki",
            dependencies: [
                .product(name: "whisper", package: "whisper.cpp"),
                .product(name: "FluidAudio", package: "FluidAudio")
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
