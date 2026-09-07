// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// apple/swift-markdown 上游不发布 semver tag，只有开发快照。为保证可复现构建，
// 这里 pin 到具体 commit（revision 即精确锁定，无需再提交 Package.resolved，
// 后者在 Xcode 与命令行 SPM 之间会产生无意义的 originHash 抖动）。
// 升级：改下面的 revision 后 `swift package update`，验证无回归即可。
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
