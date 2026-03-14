// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "XHSMarkdownKit",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "XHSMarkdownCore",
            targets: ["XHSMarkdownCore"]
        ),
        .library(
            name: "XHSMarkdownAdapterMarkdownn",
            targets: ["XHSMarkdownAdapterMarkdownn"]
        ),
        .library(
            name: "XHSMarkdownUIKit",
            targets: ["XHSMarkdownUIKit"]
        ),
        .library(
            name: "XHSMarkdownKit",
            targets: ["XHSMarkdownKit"]
        ),
        .library(
            name: "XHSMarkdownKitMarkdownn",
            targets: ["XHSMarkdownKitMarkdownn"]
        ),
    ],
    dependencies: [],
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
            name: "XHSMarkdownCore",
            path: "Sources/XHSMarkdownKit",
            sources: [
                "Contract",
                "Markdown/Parser/MarkdownContractParser.swift"
            ]
        ),
        .target(
            name: "XHSMarkdownAdapterMarkdownn",
            dependencies: [
                "XHSMarkdownCore",
                "XYMarkdown"
            ],
            path: "Sources/XHSMarkdownKit",
            sources: [
                "Markdown/Parser/XYMarkdown"
            ]
        ),
        .target(
            name: "XHSMarkdownUIKit",
            dependencies: [
                "XHSMarkdownCore"
            ],
            path: "Sources/XHSMarkdownKit",
            sources: [
                "Core",
                "Extensions",
                "Markdown/Adapter",
                "Markdown/Delegate",
                "Markdown/Theme",
                "Public"
            ]
        ),
        .target(
            name: "XHSMarkdownKit",
            dependencies: [
                "XHSMarkdownCore",
                "XHSMarkdownUIKit"
            ],
            path: "Sources/XHSMarkdownKitFacade"
        ),
        .target(
            name: "XHSMarkdownKitMarkdownn",
            dependencies: [
                "XHSMarkdownCore",
                "XHSMarkdownAdapterMarkdownn",
                "XHSMarkdownUIKit"
            ],
            path: "Sources/XHSMarkdownKitMarkdownnFacade"
        ),
        .testTarget(
            name: "XHSMarkdownKitTests",
            dependencies: [
                "XHSMarkdownKit",
                "XHSMarkdownAdapterMarkdownn"
            ],
            path: "Tests/XHSMarkdownKitTests",
            resources: [
                .copy("../Fixtures")
            ]
        ),
    ]
)
