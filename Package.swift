// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GlassPlayer",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "GlassPlayer",
            path: "Sources/GlassPlayer",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("WebKit"),
            ]
        ),
    ]
)
