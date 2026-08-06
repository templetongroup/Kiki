// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Kiki",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: "Vendor/whisper.cpp")
    ],
    targets: [
        .executableTarget(
            name: "Kiki",
            dependencies: [
                .product(name: "whisper", package: "whisper.cpp")
            ]
        )
    ]
)
