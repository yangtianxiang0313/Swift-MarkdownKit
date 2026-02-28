import UIKit

public enum InlineRenderer {

    public static func render(_ nodes: [MarkdownNode], context: RenderContext) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for node in nodes {
            result.append(renderNode(node, context: context))
        }
        return result
    }

    private static func renderNode(_ node: MarkdownNode, context: RenderContext) -> NSAttributedString {
        let theme = context.theme

        if let text = node as? TextNode {
            return NSAttributedString(string: text.text, attributes: bodyAttributes(theme: theme))
        }

        if let code = node as? InlineCodeNode {
            var attrs = bodyAttributes(theme: theme)
            attrs[.font] = theme.code.font
            attrs[.foregroundColor] = theme.code.inlineColor
            if let bg = theme.code.inlineBackgroundColor {
                attrs[.backgroundColor] = bg
            }
            return NSAttributedString(string: code.code, attributes: attrs)
        }

        if node is StrongNode {
            let inner = render(node.children, context: context)
            let mutable = NSMutableAttributedString(attributedString: inner)
            mutable.enumerateAttribute(.font, in: NSRange(location: 0, length: mutable.length)) { value, range, _ in
                if let font = value as? UIFont {
                    mutable.addAttribute(.font, value: font.bold, range: range)
                }
            }
            return mutable
        }

        if node is EmphasisNode {
            let inner = render(node.children, context: context)
            let mutable = NSMutableAttributedString(attributedString: inner)
            switch theme.emphasis.type {
            case .italic:
                applyItalic(to: mutable)
            case .highlight:
                mutable.addAttribute(.backgroundColor, value: theme.emphasis.highlightColor, range: NSRange(location: 0, length: mutable.length))
            case .both:
                applyItalic(to: mutable)
                mutable.addAttribute(.backgroundColor, value: theme.emphasis.highlightColor, range: NSRange(location: 0, length: mutable.length))
            }
            return mutable
        }

        if let link = node as? LinkNode {
            let inner = render(node.children, context: context)
            let mutable = NSMutableAttributedString(attributedString: inner)
            let range = NSRange(location: 0, length: mutable.length)
            mutable.addAttribute(.foregroundColor, value: theme.link.color, range: range)
            if let dest = link.destination, let url = URL(string: dest) {
                mutable.addAttribute(.link, value: url, range: range)
            }
            if theme.link.underlineStyle != [] {
                mutable.addAttribute(.underlineStyle, value: theme.link.underlineStyle.rawValue, range: range)
            }
            return mutable
        }

        if node is StrikethroughNode {
            let inner = render(node.children, context: context)
            let mutable = NSMutableAttributedString(attributedString: inner)
            let range = NSRange(location: 0, length: mutable.length)
            mutable.addAttribute(.strikethroughStyle, value: theme.strikethrough.style.rawValue, range: range)
            if let color = theme.strikethrough.color {
                mutable.addAttribute(.strikethroughColor, value: color, range: range)
            }
            return mutable
        }

        if node is SoftBreakNode {
            return NSAttributedString(string: " ", attributes: bodyAttributes(theme: theme))
        }

        if node is LineBreakNode {
            return NSAttributedString(string: "\n", attributes: bodyAttributes(theme: theme))
        }

        return render(node.children, context: context)
    }

    private static func applyItalic(to mutable: NSMutableAttributedString) {
        let fullRange = NSRange(location: 0, length: mutable.length)
        mutable.enumerateAttribute(.font, in: fullRange) { value, range, _ in
            if let font = value as? UIFont {
                let italicFont = font.italic
                if italicFont.isItalic {
                    mutable.addAttribute(.font, value: italicFont, range: range)
                } else {
                    mutable.addAttribute(.obliqueness, value: NSNumber(value: 0.2), range: range)
                }
            }
        }
    }

    private static func bodyAttributes(theme: MarkdownTheme) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = theme.body.lineHeight
        paragraphStyle.maximumLineHeight = theme.body.lineHeight

        return [
            .font: theme.body.font,
            .foregroundColor: theme.body.color,
            .paragraphStyle: paragraphStyle,
            .kern: theme.body.letterSpacing,
            .baselineOffset: (theme.body.lineHeight - theme.body.font.lineHeight) / 4
        ]
    }
}
