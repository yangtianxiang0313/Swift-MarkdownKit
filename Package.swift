// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "XHSMarkdownKit",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "XHSMarkdownKit",
            targets: ["XHSMarkdownKit"]
        ),
    ],
    dependencies: [
        // 本地 vendored 依赖（XYMarkdown / XYCmark）
    ],
    targets: [
        .target(
            name: "XYCmark",
            path: "Sources/XYCmark/Sources/libcmark_gfm",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include")
            ]
        ),
        .target(
            name: "CAtomic",
            path: "Sources/XYMarkdown/Sources/CAtomic",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include")
            ]
        ),
        .target(
            name: "XYMarkdown",
            dependencies: [
                "XYCmark",
                "CAtomic"
            ],
            path: "Sources/XYMarkdown/Sources/Markdown"
        ),
        .target(
            name: "XHSMarkdownKit",
            dependencies: [
                "XYMarkdown",
            ],
            path: "Sources/XHSMarkdownKit"
        ),
        .testTarget(
            name: "XHSMarkdownKitTests",
            dependencies: ["XHSMarkdownKit"],
            path: "Tests/XHSMarkdownKitTests",
            resources: [
                .copy("../Fixtures")
            ]
        ),
    ]
)
