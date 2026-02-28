import UIKit

public enum FragmentOptimizer {

    public static func optimize(
        _ fragments: [RenderFragment],
        spacingResolver: BlockSpacingResolving,
        theme: MarkdownTheme
    ) -> [RenderFragment] {
        var result = fragments

        result = merge(result)
        result = filter(result)
        setSpacing(on: &result, resolver: spacingResolver, theme: theme)

        return result
    }

    // MARK: - Merge

    private static func merge(_ fragments: [RenderFragment]) -> [RenderFragment] {
        guard fragments.count > 1 else { return fragments }
        var result: [RenderFragment] = []

        var i = 0
        while i < fragments.count {
            var current = fragments[i]
            while i + 1 < fragments.count,
                  let mergeable = current as? MergeableFragment,
                  mergeable.canMerge(with: fragments[i + 1]) {
                current = mergeable.merged(with: fragments[i + 1])
                i += 1
            }
            result.append(current)
            i += 1
        }

        return result
    }

    // MARK: - Filter

    private static func filter(_ fragments: [RenderFragment]) -> [RenderFragment] {
        fragments.filter { fragment in
            if let attrProvider = fragment as? AttributedStringProviding,
               let attrString = attrProvider.attributedString,
               attrString.length == 0 {
                return false
            }
            return true
        }
    }

    // MARK: - SetSpacing

    private static func setSpacing(
        on fragments: inout [RenderFragment],
        resolver: BlockSpacingResolving,
        theme: MarkdownTheme
    ) {
        for i in 0..<fragments.count {
            if i < fragments.count - 1 {
                fragments[i].spacingAfter = resolver.spacing(
                    after: fragments[i].nodeType,
                    before: fragments[i + 1].nodeType,
                    theme: theme
                )
            } else {
                fragments[i].spacingAfter = 0
            }
        }
    }
}
