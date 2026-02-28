import UIKit

public struct DefaultTableRenderer: LeafNodeRenderer {
    public init() {}

    public func renderLeaf(node: MarkdownNode, context: RenderContext) -> [RenderFragment] {
        guard let table = node as? TableNode else { return [] }

        let theme = context.theme
        let headers = table.headerCells.map { cells in
            InlineRenderer.render(cells, context: context)
        }
        let rows = table.bodyRows.map { row in
            row.map { cells in
                InlineRenderer.render(cells, context: context)
            }
        }
        let tableData = TableData(headers: headers, rows: rows, alignments: table.columnAlignments)

        let strategy = context[TableViewStrategyKey.self]
        let fragmentContext = context.makeFragmentContext()
        let fragmentId = context.fragmentId(nodeType: "table", index: 0)

        return [ViewFragment(
            fragmentId: fragmentId,
            nodeType: .table,
            reuseIdentifier: .markdownTableView,
            context: fragmentContext,
            content: tableData,
            totalContentLength: 1,
            enterTransition: strategy.enterTransition,
            exitTransition: strategy.exitTransition,
            makeView: { strategy.makeView() },
            configure: { view in
                strategy.configure(view: view, tableData: tableData, context: fragmentContext, theme: theme)
            }
        )]
    }
}
