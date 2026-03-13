import UIKit

public struct TableData: FragmentContent {
    public let headers: [NSAttributedString]
    public let rows: [[NSAttributedString]]
    public let alignments: [TableColumnAlignment]

    public init(headers: [NSAttributedString], rows: [[NSAttributedString]], alignments: [TableColumnAlignment]) {
        self.headers = headers
        self.rows = rows
        self.alignments = alignments
    }

    public func isEqual(to other: any FragmentContent) -> Bool {
        guard let rhs = other as? TableData else { return false }
        return alignments == rhs.alignments
            && headers.elementsEqual(rhs.headers, by: { $0.isEqual($1) })
            && rowsEqual(lhs: rows, rhs: rhs.rows)
    }

    private func rowsEqual(lhs: [[NSAttributedString]], rhs: [[NSAttributedString]]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for (lhsRow, rhsRow) in zip(lhs, rhs) {
            guard lhsRow.count == rhsRow.count else { return false }
            for (lhsCell, rhsCell) in zip(lhsRow, rhsRow) where !lhsCell.isEqual(rhsCell) {
                return false
            }
        }
        return true
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
    public static let defaultValue: TableViewStrategy = DefaultContractTableViewStrategy()
}
