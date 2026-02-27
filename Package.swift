// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "XHSMarkdownKit",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "XHSMarkdownKit",
            targets: ["XHSMarkdownKit"]
        ),
    ],
    dependencies: [
        // XYMarkdown 作为解析层
        // 注意：如果 XYMarkdown 有 SPM 支持，取消下面的注释
        // .package(url: "https://code.devops.xiaohongshu.com/xhs-ios/XYMarkdown.git", from: "0.0.2"),
    ],
    targets: [
        .target(
            name: "XHSMarkdownKit",
            dependencies: [
                // 如果 XYMarkdown 有 SPM 支持，取消下面的注释
                // "XYMarkdown",
            ],
            path: "Sources/XHSMarkdownKit"
        ),
        .testTarget(
            name: "XHSMarkdownKitTests",
            dependencies: ["XHSMarkdownKit"],
            path: "Tests/XHSMarkdownKitTests",
            resources: [
                .copy("Fixtures")
            ]
        ),
    ]
)
