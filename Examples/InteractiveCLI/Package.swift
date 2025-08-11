// swift-tools-version: 6.0
// Interactive CLI Example for ClaudeCodeSwiftSDK

import PackageDescription

let package = Package(
    name: "InteractiveCLI",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "InteractiveCLI",
            targets: ["InteractiveCLI"]
        )
    ],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "InteractiveCLI",
            dependencies: [
                .product(name: "ClaudeCodeSwiftSDK", package: "ClaudeCodeSwiftSDK")
            ],
            path: ".",
            exclude: ["README.md", ".gitignore"],
            sources: ["main.swift"]
        )
    ]
)