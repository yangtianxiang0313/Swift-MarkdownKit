import UIKit

public struct TableData {
    public let headers: [NSAttributedString]
    public let rows: [[NSAttributedString]]
    public let alignments: [TableColumnAlignment]

    public init(headers: [NSAttributedString], rows: [[NSAttributedString]], alignments: [TableColumnAlignment]) {
        self.headers = headers
        self.rows = rows
        self.alignments = alignments
    }
}

public protocol TableViewStrategy {
    func makeView() -> UIView
    func configure(view: UIView, tableData: TableData, context: FragmentContext, theme: MarkdownTheme)
    var enterTransition: (any ViewTransition)? { get }
    var exitTransition: (any ViewTransition)? { get }
}

public extension TableViewStrategy {
    var enterTransition: (any ViewTransition)? { nil }
    var exitTransition: (any ViewTransition)? { nil }
}

public enum TableViewStrategyKey: ContextKey {
    public static let defaultValue: TableViewStrategy = DefaultTableViewStrategy()
}

public struct DefaultTableViewStrategy: TableViewStrategy {
    public init() {}

    public func makeView() -> UIView {
        MarkdownTableView()
    }

    public func configure(view: UIView, tableData: TableData, context: FragmentContext, theme: MarkdownTheme) {
        guard let tableView = view as? MarkdownTableView else { return }
        
        let config = TableConfiguration(
            tableData: tableData,
            tableStyle: theme.table
        )
        
        tableView.configure(config)
    }
}
