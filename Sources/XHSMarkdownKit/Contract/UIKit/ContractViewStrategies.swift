import UIKit

public struct DefaultContractTextViewStrategy: TextViewStrategy {
    public init() {}

    public func makeView() -> UIView {
        ContractTextView()
    }

    public func configure(
        view: UIView,
        attributedString: NSAttributedString,
        context: FragmentContext,
        theme: MarkdownTheme
    ) {
        guard let textView = view as? ContractTextView else { return }
        let indent = context[IndentKey.self]
        textView.configure(attributedString: attributedString, indent: indent)
    }
}

public struct DefaultContractCodeBlockViewStrategy: CodeBlockViewStrategy {
    public init() {}

    public func makeView() -> UIView {
        ContractCodeBlockView()
    }

    public func configure(view: UIView, content: CodeBlockContent, context: FragmentContext, theme: MarkdownTheme) {
        guard let codeView = view as? ContractCodeBlockView else { return }

        let config = CodeBlockConfiguration(
            code: content.code,
            language: content.language,
            backgroundColor: theme.code.block.backgroundColor,
            font: theme.code.font,
            cornerRadius: theme.code.block.cornerRadius,
            borderWidth: theme.code.block.borderWidth,
            borderColor: theme.code.block.borderColor.cgColor,
            padding: theme.code.block.padding
        )

        codeView.configure(config)
    }
}

public struct DefaultContractImageViewStrategy: ImageViewStrategy {
    public init() {}

    public func makeView() -> UIView {
        ContractImageView()
    }

    public func configure(view: UIView, content: ImageContent, context: FragmentContext, theme: MarkdownTheme) {
        guard let imageView = view as? ContractImageView else { return }

        let config = ImageConfiguration(
            source: content.source,
            maxWidth: context[MaxWidthKey.self],
            cornerRadius: theme.image.cornerRadius,
            placeholderHeight: theme.image.placeholderHeight,
            placeholderColor: theme.image.placeholderColor,
            maxImageWidth: theme.image.maxWidth
        )

        imageView.configure(config)
    }
}

public struct DefaultContractTableViewStrategy: TableViewStrategy {
    public init() {}

    public func makeView() -> UIView {
        ContractTableView()
    }

    public func configure(view: UIView, tableData: TableData, context: FragmentContext, theme: MarkdownTheme) {
        guard let tableView = view as? ContractTableView else { return }

        let config = TableConfiguration(tableData: tableData, tableStyle: theme.table)
        tableView.configure(config)
    }
}

public struct DefaultContractThematicBreakViewStrategy: ThematicBreakViewStrategy {
    public init() {}

    public func makeView() -> UIView {
        ContractThematicBreakView()
    }

    public func configure(view: UIView, context: FragmentContext, theme: MarkdownTheme) {
        guard let breakView = view as? ContractThematicBreakView else { return }
        breakView.configure(color: theme.thematicBreak.color, height: theme.thematicBreak.height)
    }
}
