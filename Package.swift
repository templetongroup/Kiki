// swift-tools-version:6.0
import PackageDescription
import Foundation

let localSparklePath = "Vendor/Sparkle/Sparkle.xcframework"
let hasLocalSparkle = FileManager.default.fileExists(atPath: localSparklePath)

var packageDependencies: [Package.Dependency] = [
    .package(path: "Vendor/whisper.cpp"),
    .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.15.5"),
    .package(
        url: "https://github.com/Blaizzy/mlx-audio-swift.git",
        revision: "4266f988d170a83017d1e82e2e4654602f277f1d"
    ),
    .package(url: "https://github.com/ml-explore/mlx-swift.git", exact: "0.31.6"),
]
var kikiDependencies: [Target.Dependency] = [
    .product(name: "whisper", package: "whisper.cpp"),
    .product(name: "FluidAudio", package: "FluidAudio"),
    .product(name: "MLXAudioCore", package: "mlx-audio-swift"),
    .product(name: "MLXAudioTTS", package: "mlx-audio-swift"),
    .product(name: "MLX", package: "mlx-swift"),
]
var packageTargets: [Target] = []

if hasLocalSparkle {
    packageTargets.append(.binaryTarget(name: "Sparkle", path: localSparklePath))
    kikiDependencies.append(.target(name: "Sparkle"))
} else {
    packageDependencies.append(
        .package(url: "https://github.com/sparkle-project/Sparkle.git", exact: "2.9.5")
    )
    kikiDependencies.append(.product(name: "Sparkle", package: "Sparkle"))
}

packageTargets.append(
    .executableTarget(
        name: "Kiki",
        dependencies: kikiDependencies,
        swiftSettings: [.swiftLanguageMode(.v5)]
    )
)

let package = Package(
    name: "Kiki",
    platforms: [.macOS(.v14)],
    dependencies: packageDependencies,
    targets: packageTargets
)
