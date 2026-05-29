// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GhosttyClaudeBar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ghostty-claude-bar", targets: ["GhosttyClaudeBar"]),
        .library(name: "GhosttyClaudeBarCore", targets: ["GhosttyClaudeBarCore"]),
    ],
    targets: [
        // UI / menu-bar app. Owns nothing but presentation + AppKit glue.
        .executableTarget(
            name: "GhosttyClaudeBar",
            dependencies: ["GhosttyClaudeBarCore"],
            resources: [.copy("Resources/Fonts")]
        ),
        // Pure data layer — no AppKit. This is where the Python tool's brains
        // (session parsing, Ghostty enumeration, fuzzy match, verdicts) get ported.
        .target(name: "GhosttyClaudeBarCore"),
        .testTarget(
            name: "GhosttyClaudeBarCoreTests",
            dependencies: ["GhosttyClaudeBarCore"]
        ),
    ]
)
