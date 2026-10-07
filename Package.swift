// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NepaliInput",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "NepaliInput", path: "Sources/NepaliInput")
    ]
)
