// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// apple/swift-markdown 上游不发布 semver tag，只有开发快照 tag。
// 为保证可复现构建，这里 pin 到具体 commit，并将 Package.resolved 纳入版本控制。
// 升级方式：改下面的 revision（或临时切回 branch: "main"）后执行 `swift package update`，
// 确认无回归再提交新的 Package.resolved。
let swiftMarkdownRevision = "27b7fc1a19068bcea3d2072db0ce86360d1400ed"

let package = Package(
    name: "MDPreview",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MDPreviewCore",
            targets: ["MDPreviewCore"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown.git", revision: swiftMarkdownRevision)
    ],
    targets: [
        .target(
            name: "MDPreviewCore",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ],
            path: "Sources/MDPreviewCore"
        ),
        .testTarget(
            name: "MDPreviewCoreTests",
            dependencies: [
                "MDPreviewCore"
            ],
            path: "Tests/MDPreviewCoreTests"
        )
    ]
)
