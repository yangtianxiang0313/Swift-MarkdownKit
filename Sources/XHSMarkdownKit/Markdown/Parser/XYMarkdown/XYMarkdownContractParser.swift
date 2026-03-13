import Foundation
import XYMarkdown

public struct XYMarkdownContractParser: MarkdownContractParser {

    public init() {}

    public func parse(_ text: String, options: MarkdownContractParserOptions = MarkdownContractParserOptions()) -> MarkdownContract.CanonicalDocument {
        let document = Document(parsing: text, source: options.sourceURL, options: options.toXYParseOptions())
        let root = Converter().convert(markup: document, path: [])

        return MarkdownContract.CanonicalDocument(
            schemaVersion: MarkdownContract.schemaVersion,
            documentId: options.documentId,
            root: root
        )
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

    func convert(markup: Markup, path: [Int]) -> MarkdownContract.CanonicalNode {
        let kind = nodeKind(for: markup)
        let sourceKind = sourceKind(for: markup)

        let children = markup.children.enumerated().map { index, child in
            convert(markup: child, path: path + [index])
        }

        return MarkdownContract.CanonicalNode(
            id: nodeId(from: path),
            kind: kind,
            attrs: attrs(for: markup),
            children: children,
            source: MarkdownContract.SourceInfo(
                sourceKind: sourceKind,
                raw: rawSource(for: markup),
                position: sourcePosition(for: markup)
            )
        )
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

    private func nodeKind(for markup: Markup) -> MarkdownContract.NodeKind {
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
        case is InlineCode:
            return .inlineCode
        case is HTMLBlock, is InlineHTML, is BlockDirective, is CustomBlock, is CustomInline:
            return .customElement
        default:
            return .custom(String(describing: type(of: markup)))
        }
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
            return ["columnAlignments": .array(alignments)]

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
            "raw": .string(raw)
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
    }

    static func parse(_ raw: String) -> Result {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let openRange = trimmed.range(of: #"<\s*([A-Za-z][A-Za-z0-9:_-]*)\b([^>]*)>"#, options: .regularExpression) else {
            return Result(name: nil, attributes: [:])
        }

        let openingTag = String(trimmed[openRange])
        guard let name = extractTagName(from: openingTag) else {
            return Result(name: nil, attributes: [:])
        }

        let attributes = extractAttributes(from: openingTag)
        return Result(name: name, attributes: attributes)
    }

    private static func extractTagName(from openingTag: String) -> String? {
        guard let match = openingTag.range(of: #"^<\s*([A-Za-z][A-Za-z0-9:_-]*)"#, options: .regularExpression) else {
            return nil
        }

        let substring = String(openingTag[match])
        return substring
            .replacingOccurrences(of: "<", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func extractAttributes(from openingTag: String) -> [String: String] {
        let pattern = #"([A-Za-z_:][A-Za-z0-9:._-]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>/]+))"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [:]
        }

        let nsString = openingTag as NSString
        let matches = regex.matches(in: openingTag, range: NSRange(location: 0, length: nsString.length))

        var attrs: [String: String] = [:]
        attrs.reserveCapacity(matches.count)

        for match in matches {
            guard match.numberOfRanges >= 5 else { continue }
            let keyRange = match.range(at: 1)
            guard keyRange.location != NSNotFound else { continue }

            let key = nsString.substring(with: keyRange)

            let value: String
            if match.range(at: 2).location != NSNotFound {
                value = nsString.substring(with: match.range(at: 2))
            } else if match.range(at: 3).location != NSNotFound {
                value = nsString.substring(with: match.range(at: 3))
            } else if match.range(at: 4).location != NSNotFound {
                value = nsString.substring(with: match.range(at: 4))
            } else {
                value = ""
            }

            attrs[key] = value
        }

        return attrs
    }
}
