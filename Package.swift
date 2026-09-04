// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "XeneonWidgets",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "XeneonWidgetsCore",
            path: "Sources/XeneonWidgetsCore"
        ),
        .executableTarget(
            name: "XeneonWidgets",
            dependencies: ["XeneonWidgetsCore"],
            path: "Sources/XeneonWidgets",
            resources: [
                .process("Resources/XeneonWidgets.icns"),
            ],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreWLAN"),
                .linkedFramework("SystemConfiguration"),
                .linkedFramework("EventKit"),
            ]
        ),
        .executableTarget(
            name: "XeneonWidgetsSelfTest",
            dependencies: ["XeneonWidgetsCore"],
            path: "Sources/XeneonWidgetsSelfTest"
        ),
    ]
)