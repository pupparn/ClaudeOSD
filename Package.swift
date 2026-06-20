// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeUsageOSD",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ClaudeUsageOSD",
            path: "Sources/ClaudeUsageOSD"
        )
    ]
)
