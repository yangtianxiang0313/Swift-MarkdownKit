import UIKit

public protocol BlockSpacingResolving {
    func spacing(after current: FragmentNodeType, before next: FragmentNodeType, theme: MarkdownTheme) -> CGFloat
}

public struct DefaultBlockSpacingResolver: BlockSpacingResolving {
    public init() {}

    public func spacing(after current: FragmentNodeType, before next: FragmentNodeType, theme: MarkdownTheme) -> CGFloat {
        let raw = current.rawValue

        if raw.hasPrefix("heading.") {
            return theme.spacing.headingAfter
        }

        if next.rawValue.hasPrefix("heading.") {
            let level = Int(String(next.rawValue.last ?? "1")) ?? 1
            return theme.spacing.headingSpacingBefore(for: level)
        }

        if current == .blockQuote && next == .blockQuote {
            return theme.spacing.blockQuoteBetween
        }

        if current == .blockQuote || next == .blockQuote {
            return theme.spacing.blockQuoteOther
        }

        if current == .listItem && next == .listItem {
            return theme.spacing.listItem
        }

        return theme.spacing.paragraph
    }
}
