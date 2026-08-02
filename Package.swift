// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "simshot",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "simshot", targets: ["simshot"])
    ],
    targets: [
        .target(name: "SimshotCore"),
        .executableTarget(name: "simshot", dependencies: ["SimshotCore"]),
        .testTarget(name: "simshotTests", dependencies: ["SimshotCore"])
    ]
)
