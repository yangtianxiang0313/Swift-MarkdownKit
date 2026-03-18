import XCTest

final class ArchitectureGuardTests: XCTestCase {

    func testCoreLayerHasNoUIKitOrXYMarkdownImport() throws {
        let projectRoot = try projectRootURL()
        let coreContractDir = projectRoot.appendingPathComponent("Sources/XHSMarkdownKit/Contract")
        let parserProtocolFile = projectRoot.appendingPathComponent("Sources/XHSMarkdownKit/Markdown/Parser/MarkdownContractParser.swift")

        let files = try swiftFiles(in: coreContractDir) + [parserProtocolFile]
        XCTAssertFalse(files.isEmpty)

        for file in files {
            let content = try String(contentsOf: file, encoding: .utf8)
            XCTAssertFalse(content.contains("import UIKit"), "UIKit import found in core file: \(file.path)")
            XCTAssertFalse(content.contains("import XYMarkdown"), "XYMarkdown import found in core file: \(file.path)")
        }
    }

    func testRepositoryHasNoLegacyFragmentRuntimeSymbols() throws {
        let projectRoot = try projectRootURL()
        let scanRoots = [
            projectRoot.appendingPathComponent("Sources"),
            projectRoot.appendingPathComponent("Tests"),
            projectRoot.appendingPathComponent("Example/ExampleApp"),
            projectRoot.appendingPathComponent("ARCHITECTURE.md"),
            projectRoot.appendingPathComponent("CONTRACT_RENDERING_GUIDE.md")
        ]

        let forbiddenPatterns = [
            #"\bRenderFragment\b"#,
            #"\bFragmentContaining\b"#,
            #"\bFragmentDiffing\b"#,
            #"\bViewPool\b"#,
            #"\bMarkdownRenderPipeline\b"#,
            #"\bRendererRegistry\b"#,
            #"\bRewriterPipeline\b"#
        ]

        let regexes = try forbiddenPatterns.map {
            try NSRegularExpression(pattern: $0, options: [])
        }

        let files = try filesForScan(in: scanRoots)

        for file in files {
            let content = try String(contentsOf: file, encoding: .utf8)
            let range = NSRange(location: 0, length: content.utf16.count)

            for (index, regex) in regexes.enumerated() where regex.firstMatch(in: content, options: [], range: range) != nil {
                XCTFail("Forbidden legacy symbol matched in \(file.path): \(forbiddenPatterns[index])")
            }
        }
    }

    func testPackageDefaultProductsDoNotForceMarkdownnAdapter() throws {
        let projectRoot = try projectRootURL()
        let packageFile = projectRoot.appendingPathComponent("Package.swift")
        let content = try String(contentsOf: packageFile, encoding: .utf8)

        XCTAssertTrue(content.contains(#"name: "XHSMarkdownKitMarkdownn""#))
        XCTAssertFalse(
            containsRegex(
                #"name:\s*"XHSMarkdownKit"\s*,\s*dependencies:\s*\[[^\]]*"XHSMarkdownAdapterMarkdownn""#,
                in: content
            )
        )
        XCTAssertFalse(
            containsRegex(
                #"name:\s*"XHSMarkdownUIKit"\s*,\s*dependencies:\s*\[[^\]]*"XHSMarkdownAdapterMarkdownn""#,
                in: content
            )
        )
    }

    func testPodspecDefaultSubspecAndFullAggregationAreCorrect() throws {
        let projectRoot = try projectRootURL()
        let podspecFile = projectRoot.appendingPathComponent("XHSMarkdownKit.podspec")
        let content = try String(contentsOf: podspecFile, encoding: .utf8)

        XCTAssertTrue(content.contains("s.default_subspecs = ['UIKit']"))
        XCTAssertFalse(content.contains("uikit.dependency 'XHSMarkdownKit/AdapterMarkdownn'"))
        XCTAssertTrue(content.contains("s.subspec 'Full' do |full|"))
        XCTAssertTrue(content.contains("full.dependency 'XHSMarkdownKit/UIKit'"))
        XCTAssertTrue(content.contains("full.dependency 'XHSMarkdownKit/AdapterMarkdownn'"))
    }

    func testUIKitDefaultPathHasNoAdapterImports() throws {
        let projectRoot = try projectRootURL()
        let uikitRoot = projectRoot.appendingPathComponent("Sources/XHSMarkdownKit")
        let files = try swiftFiles(in: uikitRoot)

        for file in files where file.path.contains("/Public/") || file.path.contains("/Core/") || file.path.contains("/Markdown/Adapter/") {
            let content = try String(contentsOf: file, encoding: .utf8)
            XCTAssertFalse(
                content.contains("import XHSMarkdownAdapterMarkdownn"),
                "UIKit default path imports markdownn adapter: \(file.path)"
            )
        }
    }

    func testCorePipelineFilesDoNotUseCentralizedKindSwitch() throws {
        let projectRoot = try projectRootURL()
        let files = [
            projectRoot.appendingPathComponent("Sources/XHSMarkdownKit/Contract/CanonicalRenderer.swift"),
            projectRoot.appendingPathComponent("Sources/XHSMarkdownKit/Markdown/Parser/XYMarkdown/XYMarkdownContractParser.swift"),
            projectRoot.appendingPathComponent("Sources/XHSMarkdownKit/Markdown/Adapter/RenderModelUIKitAdapter.swift")
        ]

        let pattern = #"switch\s+[^\n]*\.kind\s*\{"#
        let regex = try NSRegularExpression(pattern: pattern)

        for file in files {
            let content = try String(contentsOf: file, encoding: .utf8)
            let range = NSRange(content.startIndex..<content.endIndex, in: content)
            XCTAssertNil(
                regex.firstMatch(in: content, options: [], range: range),
                "Centralized kind switch found in \(file.path)"
            )
        }
    }

    func testRepositoryHasNoDeprecatedCustomElementRendererAPIs() throws {
        let projectRoot = try projectRootURL()
        let scanRoots = [
            projectRoot.appendingPathComponent("Sources"),
            projectRoot.appendingPathComponent("Example/ExampleApp"),
            projectRoot.appendingPathComponent("Tests"),
            projectRoot.appendingPathComponent("CONTRACT_RENDERING_GUIDE.md"),
            projectRoot.appendingPathComponent("ARCHITECTURE.md")
        ]
        let files = try filesForScan(in: scanRoots)

        for file in files {
            if file.lastPathComponent == "ArchitectureGuardTests.swift" {
                continue
            }
            let content = try String(contentsOf: file, encoding: .utf8)
            XCTAssertFalse(content.contains("forCustomElement"), "Deprecated API token found in \(file.path)")
        }
    }

    func testContractRenderingGuideHasNoDeprecatedUIKitAdapterAPITokens() throws {
        let projectRoot = try projectRootURL()
        let guideFile = projectRoot.appendingPathComponent("CONTRACT_RENDERING_GUIDE.md")
        let content = try String(contentsOf: guideFile, encoding: .utf8)

        let forbiddenTokens = [
            "makeTextNode(",
            "makeCustomViewNode(",
            "registerBlockRenderer(forExtension:"
        ]

        for token in forbiddenTokens {
            XCTAssertFalse(
                content.contains(token),
                "Deprecated guide token found in \(guideFile.path): \(token)"
            )
        }
    }
}

private extension ArchitectureGuardTests {
    func projectRootURL() throws -> URL {
        let thisFile = URL(fileURLWithPath: #filePath)
        return thisFile
            .deletingLastPathComponent() // XHSMarkdownKitTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // project root
    }

    func swiftFiles(in directory: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        var files: [URL] = []
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            files.append(fileURL)
        }

        return files
    }

    func filesForScan(in roots: [URL]) throws -> [URL] {
        var files: [URL] = []

        for root in roots {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
                guard let enumerator = FileManager.default.enumerator(
                    at: root,
                    includingPropertiesForKeys: nil
                ) else { continue }

                for case let fileURL as URL in enumerator {
                    if fileURL.path.contains("/Pods/") || fileURL.path.contains("/.build/") {
                        continue
                    }

                    if ["swift", "md"].contains(fileURL.pathExtension) {
                        files.append(fileURL)
                    }
                }
            } else {
                files.append(root)
            }
        }

        return files
    }

    func containsRegex(_ pattern: String, in content: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return false
        }
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        return regex.firstMatch(in: content, options: [], range: range) != nil
    }
}
