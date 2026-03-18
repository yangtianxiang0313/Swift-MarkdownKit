import Foundation
#if canImport(XHSMarkdownCore)
import XHSMarkdownCore
#endif
import XYMarkdown

public struct XYMarkdownContractParser: MarkdownContractParser, MarkdownContract.NodeSpecRegistryProviding {
    public let nodeSpecRegistry: MarkdownContract.NodeSpecRegistry
    private let treeValidator: MarkdownContract.TreeValidator

    public init(nodeSpecRegistry: MarkdownContract.NodeSpecRegistry = .core()) {
        self.nodeSpecRegistry = nodeSpecRegistry
        self.treeValidator = MarkdownContract.TreeValidator(registry: nodeSpecRegistry)
    }

    public func parse(_ text: String, options: MarkdownContractParserOptions = MarkdownContractParserOptions()) throws -> MarkdownContract.CanonicalDocument {
        let parseOptions = options.toXYParseOptions()
        let document = Document(parsing: text, source: options.sourceURL, options: parseOptions)
        let root = Converter(
            nodeSpecRegistry: nodeSpecRegistry,
            parseOptions: parseOptions
        ).convert(markup: document, path: [])

        let canonical = MarkdownContract.CanonicalDocument(
            schemaVersion: MarkdownContract.schemaVersion,
            documentId: options.documentId,
            root: root
        )

        try canonical.validate()
        try treeValidator.validate(document: canonical)
        return canonical
    }
}

private extension MarkdownContractParserOptions {
    func toXYParseOptions() -> ParseOptions {
        var options: ParseOptions = []

        if parseBlockDirectives {
            options.insert(.parseBlockDirectives)
        }
        if parseSymbolLinks {
            options.insert(.parseSymbolLinks)
        }
        if parseMinimalDoxygen {
            options.insert(.parseMinimalDoxygen)
        }
        if disableSmartOptions {
            options.insert(.disableSmartOpts)
        }
        if disableSourcePosition {
            options.insert(.disableSourcePosOpts)
        }

        return options
    }
}

private struct Converter {
    let nodeSpecRegistry: MarkdownContract.NodeSpecRegistry
    let parseOptions: ParseOptions

    func convert(markup: Markup, path: [Int]) -> MarkdownContract.CanonicalNode {
        guard let node = convertOptional(markup: markup, path: path) else {
            preconditionFailure("Unexpected nil canonical node for \(type(of: markup)) at path \(path)")
        }
        return node
    }

    private func convertOptional(markup: Markup, path: [Int]) -> MarkdownContract.CanonicalNode? {
        let sourceKind = sourceKind(for: markup)
        let attrs = attrs(for: markup)
        if sourceKind == .htmlTag, isClosingHTMLTag(attrs: attrs) {
            return nil
        }
        let kind = nodeKind(for: markup, sourceKind: sourceKind, attrs: attrs)
        var children = convertChildren(Array(markup.children), parentPath: path)
        if children.isEmpty,
           let embeddedChildren = extractEmbeddedPairedHTMLChildrenIfNeeded(
                sourceKind: sourceKind,
                attrs: attrs,
                path: path
           ) {
            children = embeddedChildren
        }
        children = normalizeInlineChildrenIfNeeded(
            forParentKind: kind,
            children: children,
            parentPath: path
        )

        return MarkdownContract.CanonicalNode(
            id: nodeId(from: path),
            kind: kind,
            attrs: attrs,
            children: children,
            source: MarkdownContract.SourceInfo(
                sourceKind: sourceKind,
                raw: rawSource(for: markup),
                position: sourcePosition(for: markup)
            )
        )
    }

    private func convertChildren(
        _ children: [Markup],
        parentPath: [Int]
    ) -> [MarkdownContract.CanonicalNode] {
        var converted: [MarkdownContract.CanonicalNode] = []
        var index = 0

        while index < children.count {
            let child = children[index]
            let childPath = parentPath + [index]
            let sourceKind = sourceKind(for: child)
            let attrs = attrs(for: child)

            if let paired = makePairedHTMLTagNodeIfNeeded(
                child: child,
                childAttrs: attrs,
                sourceKind: sourceKind,
                path: childPath,
                siblingMarkup: children,
                siblingIndex: index
            ) {
                converted.append(paired.node)
                index = paired.nextIndex
                continue
            }

            if let node = convertOptional(markup: child, path: childPath) {
                converted.append(node)
            }
            index += 1
        }

        return converted
    }

    private func normalizeInlineChildrenIfNeeded(
        forParentKind parentKind: MarkdownContract.NodeKind,
        children: [MarkdownContract.CanonicalNode],
        parentPath: [Int]
    ) -> [MarkdownContract.CanonicalNode] {
        guard !children.isEmpty,
              let parentSpec = nodeSpecRegistry.spec(for: parentKind) else {
            return children
        }

        let allowedRoles = parentSpec.childPolicy.allowedChildRoles
        let allowsInline = allowedRoles.contains(.inlineLeaf) || allowedRoles.contains(.inlineContainer)
        guard !allowsInline else {
            return children
        }

        let allowsBlock = allowedRoles.contains(.blockLeaf) || allowedRoles.contains(.blockContainer)
        guard allowsBlock else {
            return children
        }

        let hasInlineChildren = children.contains { child in
            guard let role = nodeSpecRegistry.spec(for: child.kind)?.role else { return false }
            return role.isInline
        }
        guard hasInlineChildren else {
            return children
        }

        var normalized: [MarkdownContract.CanonicalNode] = []
        var inlineBuffer: [MarkdownContract.CanonicalNode] = []
        var paragraphSeed = 0

        func flushInlineBuffer() {
            guard !inlineBuffer.isEmpty else { return }
            let paragraph = MarkdownContract.CanonicalNode(
                id: "\(nodeId(from: parentPath)).autoParagraph.\(paragraphSeed)",
                kind: .paragraph,
                attrs: [:],
                children: inlineBuffer,
                source: inlineBuffer.first?.source ?? MarkdownContract.SourceInfo(sourceKind: .markdown, raw: nil, position: nil)
            )
            normalized.append(paragraph)
            inlineBuffer.removeAll(keepingCapacity: true)
            paragraphSeed += 1
        }

        for child in children {
            guard let role = nodeSpecRegistry.spec(for: child.kind)?.role else {
                flushInlineBuffer()
                normalized.append(child)
                continue
            }

            if role.isInline {
                inlineBuffer.append(child)
            } else {
                flushInlineBuffer()
                normalized.append(child)
            }
        }
        flushInlineBuffer()

        return normalized
    }

    private func makePairedHTMLTagNodeIfNeeded(
        child: Markup,
        childAttrs: [String: MarkdownContract.Value],
        sourceKind: MarkdownContract.SourceKind,
        path: [Int],
        siblingMarkup: [Markup],
        siblingIndex: Int
    ) -> (node: MarkdownContract.CanonicalNode, nextIndex: Int)? {
        guard sourceKind == .htmlTag else { return nil }
        guard !isClosingHTMLTag(attrs: childAttrs) else { return nil }
        guard !isSelfClosingHTMLTag(attrs: childAttrs) else { return nil }

        guard let tagName = htmlTagName(from: childAttrs),
              let pairingMode = nodeSpecRegistry.tagPairingMode(forHTMLTagName: tagName),
              pairingMode.supportsPaired
        else {
            return nil
        }

        guard let closingIndex = findMatchingClosingTagIndex(
            for: tagName,
            in: siblingMarkup,
            start: siblingIndex + 1
        ) else {
            return nil
        }

        let innerMarkup = Array(siblingMarkup[(siblingIndex + 1)..<closingIndex])
        let children = convertChildren(innerMarkup, parentPath: path)
        let kind = nodeKind(for: child, sourceKind: sourceKind, attrs: childAttrs)

        let node = MarkdownContract.CanonicalNode(
            id: nodeId(from: path),
            kind: kind,
            attrs: childAttrs,
            children: children,
            source: MarkdownContract.SourceInfo(
                sourceKind: sourceKind,
                raw: rawSource(for: child),
                position: sourcePosition(for: child)
            )
        )
        return (node, closingIndex + 1)
    }

    private func extractEmbeddedPairedHTMLChildrenIfNeeded(
        sourceKind: MarkdownContract.SourceKind,
        attrs: [String: MarkdownContract.Value],
        path: [Int]
    ) -> [MarkdownContract.CanonicalNode]? {
        guard sourceKind == .htmlTag else { return nil }
        guard !isClosingHTMLTag(attrs: attrs) else { return nil }
        guard !isSelfClosingHTMLTag(attrs: attrs) else { return nil }
        guard let tagName = htmlTagName(from: attrs),
              let pairingMode = nodeSpecRegistry.tagPairingMode(forHTMLTagName: tagName),
              pairingMode.supportsPaired else {
            return nil
        }
        guard let raw = rawHTML(from: attrs),
              let innerMarkdown = extractInnerMarkdown(rawHTML: raw, tagName: tagName),
              !innerMarkdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let innerDocument = Document(parsing: innerMarkdown, options: parseOptions)
        return convertChildren(Array(innerDocument.children), parentPath: path)
    }

    private func findMatchingClosingTagIndex(
        for tagName: String,
        in siblings: [Markup],
        start: Int
    ) -> Int? {
        guard start < siblings.count else { return nil }

        var depth = 0
        var index = start
        while index < siblings.count {
            let candidate = siblings[index]
            let sourceKind = sourceKind(for: candidate)
            if sourceKind != .htmlTag {
                index += 1
                continue
            }

            let candidateAttrs = attrs(for: candidate)
            guard let candidateName = htmlTagName(from: candidateAttrs),
                  candidateName == tagName
            else {
                index += 1
                continue
            }

            if isClosingHTMLTag(attrs: candidateAttrs) {
                if depth == 0 {
                    return index
                }
                depth -= 1
                index += 1
                continue
            }

            if let pairingMode = nodeSpecRegistry.tagPairingMode(forHTMLTagName: candidateName),
               pairingMode.supportsPaired,
               !isSelfClosingHTMLTag(attrs: candidateAttrs) {
                depth += 1
            }
            index += 1
        }

        return nil
    }

    private func isClosingHTMLTag(attrs: [String: MarkdownContract.Value]) -> Bool {
        if case let .bool(value)? = attrs["isClosing"] {
            return value
        }
        return false
    }

    private func isSelfClosingHTMLTag(attrs: [String: MarkdownContract.Value]) -> Bool {
        if case let .bool(value)? = attrs["isSelfClosing"] {
            return value
        }
        if case let .string(raw)? = attrs["raw"] {
            return raw.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("/>")
        }
        return false
    }

    private func htmlTagName(from attrs: [String: MarkdownContract.Value]) -> String? {
        guard case let .string(raw)? = attrs["name"] else { return nil }
        return raw.lowercased()
    }

    private func rawHTML(from attrs: [String: MarkdownContract.Value]) -> String? {
        guard case let .string(raw)? = attrs["raw"] else { return nil }
        return raw
    }

    private func extractInnerMarkdown(rawHTML: String, tagName: String) -> String? {
        let escapedTagName = NSRegularExpression.escapedPattern(for: tagName)
        let pattern = #"(?is)^\s*<\s*"# + escapedTagName + #"\b[^>]*>(.*)</\s*"# + escapedTagName + #"\s*>\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(rawHTML.startIndex..<rawHTML.endIndex, in: rawHTML)
        guard let match = regex.firstMatch(in: rawHTML, options: [], range: range),
              match.numberOfRanges > 1,
              let contentRange = Range(match.range(at: 1), in: rawHTML) else {
            return nil
        }
        return String(rawHTML[contentRange])
    }

    private func nodeId(from path: [Int]) -> String {
        guard !path.isEmpty else { return "root" }
        return "n." + path.map(String.init).joined(separator: ".")
    }

    private func sourceKind(for markup: Markup) -> MarkdownContract.SourceKind {
        switch markup {
        case is BlockDirective:
            return .directive
        case is HTMLBlock, is InlineHTML:
            return .htmlTag
        case let customInline as CustomInline where looksLikeHTMLTag(customInline.text):
            return .htmlTag
        default:
            return .markdown
        }
    }

    private func sourcePosition(for markup: Markup) -> MarkdownContract.SourcePosition? {
        guard let range = markup.range else { return nil }
        return MarkdownContract.SourcePosition(
            startLine: range.lowerBound.line,
            startColumn: range.lowerBound.column,
            endLine: range.upperBound.line,
            endColumn: range.upperBound.column
        )
    }

    private func nodeKind(
        for markup: Markup,
        sourceKind: MarkdownContract.SourceKind,
        attrs: [String: MarkdownContract.Value]
    ) -> MarkdownContract.NodeKind {
        switch markup {
        case is Document:
            return .document
        case is Paragraph:
            return .paragraph
        case is Heading:
            return .heading
        case is OrderedList, is UnorderedList:
            return .list
        case is ListItem:
            return .listItem
        case is BlockQuote:
            return .blockQuote
        case is CodeBlock:
            return .codeBlock
        case is Table:
            return .table
        case is Table.Head:
            return .tableHead
        case is Table.Body:
            return .tableBody
        case is Table.Row:
            return .tableRow
        case is Table.Cell:
            return .tableCell
        case is ThematicBreak:
            return .thematicBreak
        case is Image:
            return .image
        case is Text:
            return .text
        case is Link:
            return .link
        case is Emphasis:
            return .emphasis
        case is Strong:
            return .strong
        case is Strikethrough:
            return .strikethrough
        case is InlineCode:
            return .inlineCode
        case is SoftBreak:
            return .softBreak
        case is LineBreak:
            return .hardBreak
        case is HTMLBlock, is InlineHTML, is BlockDirective, is CustomBlock, is CustomInline:
            return resolveExtensionKind(markup: markup, sourceKind: sourceKind, attrs: attrs)
        default:
            return resolveExtensionKind(markup: markup, sourceKind: sourceKind, attrs: attrs)
        }
    }

    private func resolveExtensionKind(
        markup: Markup,
        sourceKind: MarkdownContract.SourceKind,
        attrs: [String: MarkdownContract.Value]
    ) -> MarkdownContract.NodeKind {
        if case let .string(name)? = attrs["name"],
           let resolved = nodeSpecRegistry.resolveKind(sourceKind: sourceKind, name: name) {
            return resolved
        }

        let fallbackName: String
        if case let .string(name)? = attrs["name"] {
            fallbackName = sanitizeKindName(name)
        } else {
            fallbackName = sanitizeKindName(String(describing: type(of: markup)))
        }

        return .ext(.init(namespace: "unregistered", name: fallbackName))
    }

    private func sanitizeKindName(_ value: String) -> String {
        let lower = value.lowercased()
        let scalar = lower.map { char -> Character in
            if char.isLetter || char.isNumber || char == "_" || char == "-" {
                return char
            }
            return "_"
        }
        return String(scalar)
    }

    private func rawSource(for markup: Markup) -> String? {
        if let html = markup as? HTMLBlock {
            return html.rawHTML
        }
        if let inlineHTML = markup as? InlineHTML {
            return inlineHTML.rawHTML
        }
        if let customInline = markup as? CustomInline {
            return customInline.text
        }
        if let text = markup as? Text {
            return text.string
        }
        if let code = markup as? CodeBlock {
            return code.code
        }
        return nil
    }

    private func attrs(for markup: Markup) -> [String: MarkdownContract.Value] {
        switch markup {
        case let heading as Heading:
            return ["level": .int(heading.level)]

        case let orderedList as OrderedList:
            return [
                "ordered": .bool(true),
                "startIndex": .int(Int(orderedList.startIndex))
            ]

        case is UnorderedList:
            return ["ordered": .bool(false)]

        case let listItem as ListItem:
            guard let checkbox = listItem.checkbox else { return [:] }
            return ["checkbox": .bool(checkbox == .checked)]

        case let codeBlock as CodeBlock:
            var result: [String: MarkdownContract.Value] = ["code": .string(codeBlock.code)]
            if let language = codeBlock.language {
                result["language"] = .string(language)
            }
            return result

        case let table as Table:
            let alignments: [MarkdownContract.Value] = table.columnAlignments.map { alignment in
                switch alignment {
                case .left: return .string("left")
                case .center: return .string("center")
                case .right: return .string("right")
                case nil: return .null
                @unknown default: return .null
                }
            }
            let headers = table.head.cells.map { MarkdownContract.Value.string($0.plainText) }
            let rows = table.body.rows.map { row in
                MarkdownContract.Value.array(row.cells.map { .string($0.plainText) })
            }
            return [
                "columnAlignments": .array(alignments),
                "alignments": .array(alignments),
                "headers": .array(Array(headers)),
                "rows": .array(Array(rows))
            ]

        case let image as Image:
            var result: [String: MarkdownContract.Value] = [
                "altText": .string(image.plainText)
            ]
            if let source = image.source {
                result["source"] = .string(source)
            }
            if let title = image.title {
                result["title"] = .string(title)
            }
            return result

        case let text as Text:
            return ["text": .string(text.string)]

        case let link as Link:
            var result: [String: MarkdownContract.Value] = [:]
            if let destination = link.destination {
                result["destination"] = .string(destination)
            }
            if let title = link.title {
                result["title"] = .string(title)
            }
            return result

        case let inlineCode as InlineCode:
            return ["code": .string(inlineCode.code)]

        case let blockDirective as BlockDirective:
            return attrsForDirective(blockDirective)

        case let htmlBlock as HTMLBlock:
            return attrsForHTML(raw: htmlBlock.rawHTML)

        case let inlineHTML as InlineHTML:
            return attrsForHTML(raw: inlineHTML.rawHTML)

        case let customInline as CustomInline:
            if looksLikeHTMLTag(customInline.text) {
                return attrsForHTML(raw: customInline.text)
            }
            return [
                "customType": .string("customInline"),
                "text": .string(customInline.text)
            ]

        case is CustomBlock:
            return ["customType": .string("customBlock")]

        default:
            return [:]
        }
    }

    private func attrsForDirective(_ directive: BlockDirective) -> [String: MarkdownContract.Value] {
        let argumentText = directive.argumentText.segments
            .map { $0.untrimmedText }
            .joined(separator: "\n")

        var result: [String: MarkdownContract.Value] = [
            "customType": .string("directive"),
            "name": .string(directive.name)
        ]

        if !argumentText.isEmpty {
            result["argumentText"] = .string(argumentText)
        }

        return result
    }

    private func attrsForHTML(raw: String) -> [String: MarkdownContract.Value] {
        let parsed = HTMLTagExtractor.parse(raw)
        var result: [String: MarkdownContract.Value] = [
            "customType": .string("htmlTag"),
            "raw": .string(raw),
            "isClosing": .bool(parsed.isClosing),
            "isSelfClosing": .bool(parsed.isSelfClosing)
        ]

        if let tagName = parsed.name {
            result["name"] = .string(tagName)
        }

        if !parsed.attributes.isEmpty {
            let attrs = parsed.attributes.mapValues(MarkdownContract.Value.string)
            result["attributes"] = .object(attrs)
        }

        return result
    }

    private func looksLikeHTMLTag(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("<") && trimmed.contains(">")
    }
}

private enum HTMLTagExtractor {
    struct Result {
        let name: String?
        let attributes: [String: String]
        let isClosing: Bool
        let isSelfClosing: Bool
    }

    static func parse(_ raw: String) -> Result {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let regex = try? NSRegularExpression(
            pattern: #"<\s*(/)?\s*([A-Za-z][A-Za-z0-9:_-]*)\b([^>]*)>"#,
            options: []
        ) else {
            return Result(name: nil, attributes: [:], isClosing: false, isSelfClosing: false)
        }
        let nsRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, options: [], range: nsRange) else {
            return Result(name: nil, attributes: [:], isClosing: false, isSelfClosing: false)
        }

        let isClosing = match.range(at: 1).location != NSNotFound
        guard let nameRange = Range(match.range(at: 2), in: trimmed) else {
            return Result(name: nil, attributes: [:], isClosing: isClosing, isSelfClosing: false)
        }
        let name = String(trimmed[nameRange])

        let openingTag: String
        if let fullRange = Range(match.range(at: 0), in: trimmed) {
            openingTag = String(trimmed[fullRange])
        } else {
            openingTag = trimmed
        }
        let isSelfClosing = !isClosing && openingTag.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("/>")
        let attributes = isClosing ? [:] : extractAttributes(from: openingTag)
        return Result(name: name, attributes: attributes, isClosing: isClosing, isSelfClosing: isSelfClosing)
    }

    private static func extractAttributes(from openingTag: String) -> [String: String] {
        guard let regex = try? NSRegularExpression(pattern: #"([A-Za-z_:][A-Za-z0-9:._-]*)\s*=\s*\"([^\"]*)\""#, options: []) else {
            return [:]
        }

        let range = NSRange(location: 0, length: openingTag.utf16.count)
        let matches = regex.matches(in: openingTag, options: [], range: range)

        var attributes: [String: String] = [:]
        for match in matches {
            guard match.numberOfRanges == 3,
                  let keyRange = Range(match.range(at: 1), in: openingTag),
                  let valueRange = Range(match.range(at: 2), in: openingTag)
            else { continue }

            attributes[String(openingTag[keyRange])] = String(openingTag[valueRange])
        }

        return attributes
    }
}
