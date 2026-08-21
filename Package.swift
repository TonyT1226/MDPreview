// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MDPreview",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "MDPreview",
            targets: ["MDPreview"]
        ),
        .executable(
            name: "VerifyTool",
            targets: ["VerifyTool"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown.git", branch: "main")
    ],
    targets: [
        .target(
            name: "MDPreviewCore",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ],
            path: "Sources/MDPreviewCore"
        ),
        .executableTarget(
            name: "MDPreview",
            dependencies: [
                "MDPreviewCore"
            ],
            path: "Sources/MDPreviewApp"
        ),
        .executableTarget(
            name: "VerifyTool",
            dependencies: [
                "MDPreviewCore"
            ],
            path: "Sources/VerifyTool"
        )
    ]
)
