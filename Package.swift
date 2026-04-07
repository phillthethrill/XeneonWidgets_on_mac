// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "XeneonWidgets",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "XeneonWidgets",
            path: "Sources/XeneonWidgets"
        )
    ]
)
