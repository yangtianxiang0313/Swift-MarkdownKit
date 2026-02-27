import Foundation
import UIKit
import XYMarkdown

// MARK: - MarkdownTableView

/// Markdown 表格视图
/// 支持横向滚动（列数多时）和纵向滚动（行数多时）
/// 支持最大高度限制，超出部分可滚动查看
public final class MarkdownTableView: UIView, FragmentConfigurable, StreamableContent, SimpleStreamableContent {

    public var totalLength: Int { 0 }
    
    // MARK: - UI Elements
    
    /// 滚动容器（同时支持横向和纵向滚动）
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = true
        sv.showsVerticalScrollIndicator = true
        sv.alwaysBounceHorizontal = false
        sv.alwaysBounceVertical = false
        return sv
    }()
    
    /// 表格内容容器
    private let contentView = UIView()
    
    // MARK: - State
    
    private var tableData: TableData?
    private var cellViews: [[UITextView]] = []  // 使用 UITextView 支持富文本
    private var theme: MarkdownTheme = .default
    private var availableWidth: CGFloat = 0
    
    /// 列宽度缓存
    private var columnWidths: [CGFloat] = []
    
    /// 行高度缓存
    private var rowHeights: [CGFloat] = []
    
    /// 表格实际总高度（不受限制）
    private var actualTotalHeight: CGFloat = 0
    
    // MARK: - Height Calculation
    
    /// 受限后的显示高度
    private var limitedDisplayHeight: CGFloat {
        if let maxHeight = theme.table.maxDisplayHeight {
            return min(actualTotalHeight, maxHeight)
        }
        return actualTotalHeight
    }
    
    // MARK: - Computed Properties (from theme)
    
    private var tableStyle: MarkdownTheme.TableStyle { theme.table }
    
    private var columnCount: Int {
        tableData?.headers.count ?? 0
    }
    
    private var rowCount: Int {
        (tableData?.rows.count ?? 0) + TableLayoutConstants.headerRowOffset
    }
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        clipsToBounds = true
        addSubview(scrollView)
        scrollView.addSubview(contentView)
    }
    
    // MARK: - FragmentConfigurable
    
    public func configure(content: Any, theme: MarkdownTheme) {
        guard let data = content as? TableData else { return }
        
        self.tableData = data
        self.theme = theme
        self.availableWidth = bounds.width
        
        applyTheme()
        rebuildCells()
        calculateSizes()
        setNeedsLayout()
    }
    
    private func applyTheme() {
        layer.borderColor = tableStyle.borderColor.cgColor
        layer.borderWidth = tableStyle.borderWidth
        layer.cornerRadius = tableStyle.cornerRadius
    }
    
    private func rebuildCells() {
        // 清除旧的 cells
        cellViews.flatMap { $0 }.forEach { $0.removeFromSuperview() }
        cellViews.removeAll()
        
        guard let data = tableData, !data.headers.isEmpty else { return }
        
        // 创建表头 cells
        var headerRow: [UITextView] = []
        for (colIndex, header) in data.headers.enumerated() {
            let alignment = data.alignments[safe: colIndex] ?? nil
            let cell = createCellView(attributedText: header, isHeader: true, alignment: alignment)
            contentView.addSubview(cell)
            headerRow.append(cell)
        }
        cellViews.append(headerRow)
        
        // 创建数据行 cells
        for row in data.rows {
            var rowCells: [UITextView] = []
            for (colIndex, cellText) in row.enumerated() {
                let alignment = data.alignments[safe: colIndex] ?? nil
                let cell = createCellView(attributedText: cellText, isHeader: false, alignment: alignment)
                contentView.addSubview(cell)
                rowCells.append(cell)
            }
            // 补齐列数
            while rowCells.count < data.headers.count {
                let cell = createCellView(attributedText: NSAttributedString(string: ""), isHeader: false)
                contentView.addSubview(cell)
                rowCells.append(cell)
            }
            cellViews.append(rowCells)
        }
    }
    
    private func createCellView(attributedText: NSAttributedString, isHeader: Bool, alignment: Table.ColumnAlignment? = nil) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = isHeader ? tableStyle.headerBackgroundColor : tableStyle.cellBackgroundColor
        textView.textContainerInset = tableStyle.cellPadding
        textView.textContainer.lineFragmentPadding = TextViewConstants.lineFragmentPadding
        
        // 设置富文本
        textView.attributedText = attributedText
        
        // 对齐方式
        switch alignment {
        case .center:
            textView.textAlignment = .center
        case .right:
            textView.textAlignment = .right
        default:
            textView.textAlignment = .left
        }
        
        return textView
    }
    
    // MARK: - Size Calculation
    
    private func calculateSizes() {
        guard !cellViews.isEmpty, columnCount > 0 else { return }
        
        let padding = tableStyle.cellPadding
        let minColumnWidth = tableStyle.minColumnWidth
        let maxColumnWidth = tableStyle.maxColumnWidth
        let minRowHeight = tableStyle.minRowHeight
        
        // 计算每列的最大宽度
        columnWidths = Array(repeating: minColumnWidth, count: columnCount)
        
        for row in cellViews {
            for (colIndex, cell) in row.enumerated() where colIndex < columnCount {
                let textWidth = cell.attributedText?.boundingRect(
                    with: CGSize(width: maxColumnWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                ).width ?? 0
                
                let cellWidth = ceil(textWidth) + padding.left + padding.right
                columnWidths[colIndex] = max(columnWidths[colIndex], min(cellWidth, maxColumnWidth))
            }
        }
        
        // 计算每行高度
        rowHeights = []
        for row in cellViews {
            var maxRowHeight: CGFloat = 0
            for (colIndex, cell) in row.enumerated() where colIndex < columnCount {
                let cellHeight = cell.attributedText?.boundingRect(
                    with: CGSize(width: columnWidths[colIndex] - padding.left - padding.right, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                ).height ?? 0
                
                maxRowHeight = max(maxRowHeight, ceil(cellHeight) + padding.top + padding.bottom)
            }
            rowHeights.append(max(maxRowHeight, minRowHeight))
        }
        
        // 计算实际总高度
        let borderWidth = tableStyle.borderWidth
        actualTotalHeight = rowHeights.reduce(0, +) + borderWidth * CGFloat(max(0, rowHeights.count - 1))
    }
    
    // MARK: - Layout
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        scrollView.frame = bounds
        
        guard !cellViews.isEmpty, columnCount > 0, !columnWidths.isEmpty, !rowHeights.isEmpty else { return }
        
        let borderWidth = tableStyle.borderWidth
        
        // 计算总宽度
        let totalWidth = columnWidths.reduce(0, +) + borderWidth * CGFloat(columnCount - 1)
        let totalHeight = rowHeights.reduce(0, +) + borderWidth * CGFloat(rowHeights.count - 1)
        
        contentView.frame = CGRect(x: 0, y: 0, width: totalWidth, height: totalHeight)
        scrollView.contentSize = CGSize(width: totalWidth, height: totalHeight)
        
        // 布局每个 cell
        var y: CGFloat = 0
        for (rowIndex, row) in cellViews.enumerated() {
            var x: CGFloat = 0
            let rowHeight = rowHeights[safe: rowIndex] ?? tableStyle.minRowHeight
            
            for (colIndex, cell) in row.enumerated() where colIndex < columnCount {
                let colWidth = columnWidths[colIndex]
                cell.frame = CGRect(x: x, y: y, width: colWidth, height: rowHeight)
                x += colWidth + borderWidth
            }
            
            y += rowHeight + borderWidth
        }
    }
    
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        guard !cellViews.isEmpty, columnCount > 0, !rowHeights.isEmpty else {
            return CGSize(width: size.width, height: tableStyle.defaultHeight)
        }

        // 使用协议的 limitedDisplayHeight（自动应用最大高度限制）
        return CGSize(width: size.width, height: limitedDisplayHeight)
    }

    // MARK: - 静态高度计算

    /// 按显示进度计算预估高度
    /// - Note: displayedLength 对表格无意义，始终返回完整高度
    public static func estimatedHeight(
        data: TableData,
        displayedLength: Int,
        maxWidth: CGFloat,
        theme: MarkdownTheme
    ) -> CGFloat {
        data.calculateEstimatedHeight(maxWidth: maxWidth, theme: theme)
    }
}
