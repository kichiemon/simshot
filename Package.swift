// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "simcap",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "simcap", targets: ["simcap"])
    ],
    targets: [
        .target(name: "SimcapCore"),
        .executableTarget(name: "simcap", dependencies: ["SimcapCore"]),
        .testTarget(name: "simcapTests", dependencies: ["SimcapCore"])
    ]
)
