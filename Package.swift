// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FIELD",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "FieldCore", targets: ["FieldCore"]),
        .library(name: "FieldMCP", targets: ["FieldMCP"]),
        .executable(name: "FIELD", targets: ["FIELD"])
    ],
    dependencies: [
        // Pin the pre-1.0 SDK so a future minor release cannot silently change
        // the MCP transport or handler APIs underneath the app.
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", exact: "0.12.1")
    ],
    targets: [
        .target(
            name: "FieldCore",
            path: "Sources/FieldCore"
        ),
        .target(
            name: "FieldMCP",
            dependencies: [
                "FieldCore",
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Sources/FieldMCP"
        ),
        .executableTarget(
            name: "FIELD",
            dependencies: [
                "FieldCore",
                "FieldMCP",
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Sources/FIELD"
        ),
        .testTarget(
            name: "FieldCoreTests",
            dependencies: ["FieldCore"],
            path: "Tests/FieldCoreTests"
        ),
        .testTarget(
            name: "FieldMCPTests",
            dependencies: [
                "FieldCore",
                "FieldMCP",
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Tests/FieldMCPTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
