// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SoundlyCore",
    platforms: [.iOS("26.0"), .macOS(.v15)],
    products: [.library(name: "SoundlyCore", targets: ["SoundlyCore"])],
    targets: [
        .target(name: "SoundlyCore"),
        .testTarget(name: "SoundlyCoreTests", dependencies: ["SoundlyCore"])
    ],
    swiftLanguageModes: [.v6]
)
