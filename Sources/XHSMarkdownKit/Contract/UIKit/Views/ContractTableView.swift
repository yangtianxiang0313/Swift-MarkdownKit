import UIKit

public final class ContractTableView: UIView, HeightEstimatable {

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = true
        sv.showsVerticalScrollIndicator = false
        sv.alwaysBounceHorizontal = true
        return sv
    }()

    private let contentView = ContractTableContentView()
    private var config: TableConfiguration?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        addSubview(scrollView)
        scrollView.addSubview(contentView)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    public func configure(_ config: TableConfiguration) {
        self.config = config
        contentView.tableData = config.tableData
        contentView.tableStyle = config.tableStyle
        contentView.setNeedsDisplay()
        setNeedsLayout()
    }

    public func estimatedHeight(atDisplayedLength: Int, maxWidth: CGFloat) -> CGFloat {
        guard let data = contentView.tableData else { return 44 }
        let rowHeight = contentView.rowHeight
        let rowCount = data.rows.count + 1
        return CGFloat(rowCount) * rowHeight + 1
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds

        guard let data = contentView.tableData else { return }
        let colWidths = contentView.calculateColumnWidths(availableWidth: bounds.width)
        let totalWidth = max(bounds.width, colWidths.reduce(0, +))
        let rowCount = data.rows.count + 1
        let totalHeight = CGFloat(rowCount) * contentView.rowHeight + 1

        contentView.columnWidths = colWidths
        contentView.frame = CGRect(x: 0, y: 0, width: totalWidth, height: totalHeight)
        scrollView.contentSize = CGSize(width: totalWidth, height: totalHeight)
        contentView.setNeedsDisplay()
    }
}

private final class ContractTableContentView: UIView {

    var tableData: TableData?
    var tableStyle: MarkdownTheme.TableStyle = .default
    var columnWidths: [CGFloat] = []

    var rowHeight: CGFloat {
        tableStyle.cellPadding.top + tableStyle.cellPadding.bottom + 22
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func calculateColumnWidths(availableWidth: CGFloat) -> [CGFloat] {
        guard let data = tableData else { return [] }
        let colCount = max(data.headers.count, 1)
        let padding = tableStyle.cellPadding.left + tableStyle.cellPadding.right
        var widths = [CGFloat](repeating: 0, count: colCount)

        let maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        for (i, header) in data.headers.enumerated() where i < colCount {
            let size = header.boundingRect(with: maxSize, options: [.usesLineFragmentOrigin], context: nil).size
            widths[i] = max(widths[i], ceil(size.width) + padding)
        }

        for row in data.rows {
            for (i, cell) in row.enumerated() where i < colCount {
                let size = cell.boundingRect(with: maxSize, options: [.usesLineFragmentOrigin], context: nil).size
                widths[i] = max(widths[i], ceil(size.width) + padding)
            }
        }

        let minWidth: CGFloat = 60
        widths = widths.map { max($0, minWidth) }

        let total = widths.reduce(0, +)
        if total < availableWidth {
            let extra = (availableWidth - total) / CGFloat(colCount)
            widths = widths.map { $0 + extra }
        }

        return widths
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let data = tableData, let ctx = UIGraphicsGetCurrentContext() else { return }
        guard !columnWidths.isEmpty else { return }

        let rowHeight = self.rowHeight

        ctx.setStrokeColor(tableStyle.borderColor.cgColor)
        ctx.setLineWidth(0.5)

        ctx.setFillColor(tableStyle.headerBackgroundColor.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: bounds.width, height: rowHeight))

        drawRow(ctx: ctx, cells: data.headers, alignments: data.alignments, y: 0, rowHeight: rowHeight)

        for (row, rowData) in data.rows.enumerated() {
            let y = CGFloat(row + 1) * rowHeight
            if row % 2 == 1 {
                ctx.setFillColor(tableStyle.headerBackgroundColor.withAlphaComponent(0.3).cgColor)
                ctx.fill(CGRect(x: 0, y: y, width: bounds.width, height: rowHeight))
            }
            drawRow(ctx: ctx, cells: rowData, alignments: data.alignments, y: y, rowHeight: rowHeight)
        }

        let totalRows = data.rows.count + 1
        ctx.setStrokeColor(tableStyle.borderColor.cgColor)
        ctx.setLineWidth(0.5)

        for row in 0...totalRows {
            let y = CGFloat(row) * rowHeight
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: bounds.width, y: y))
        }

        var x: CGFloat = 0
        for width in columnWidths {
            ctx.move(to: CGPoint(x: x, y: 0))
            ctx.addLine(to: CGPoint(x: x, y: CGFloat(totalRows) * rowHeight))
            x += width
        }
        ctx.move(to: CGPoint(x: bounds.width, y: 0))
        ctx.addLine(to: CGPoint(x: bounds.width, y: CGFloat(totalRows) * rowHeight))

        ctx.strokePath()
    }

    private func drawRow(
        ctx: CGContext,
        cells: [NSAttributedString],
        alignments: [TableColumnAlignment],
        y: CGFloat,
        rowHeight: CGFloat
    ) {
        var x: CGFloat = 0
        for (col, cell) in cells.enumerated() where col < columnWidths.count {
            let colW = columnWidths[col]
            let padding = tableStyle.cellPadding
            let availableW = colW - padding.left - padding.right

            let size = cell.boundingRect(
                with: CGSize(width: availableW, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin],
                context: nil
            ).size

            let alignment = col < alignments.count ? alignments[col] : .left
            let drawX: CGFloat
            switch alignment {
            case .center:
                drawX = x + padding.left + (availableW - ceil(size.width)) / 2
            case .right:
                drawX = x + colW - padding.right - ceil(size.width)
            default:
                drawX = x + padding.left
            }

            let drawY = y + (rowHeight - ceil(size.height)) / 2
            cell.draw(in: CGRect(x: drawX, y: drawY, width: ceil(size.width), height: ceil(size.height)))

            x += colW
        }
    }
}
