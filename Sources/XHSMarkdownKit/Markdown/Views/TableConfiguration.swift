import UIKit

/// MarkdownTableView 的配置结构体
public struct TableConfiguration {
    
    // MARK: - 内容
    
    public let tableData: TableData
    
    // MARK: - 样式配置
    
    public let tableStyle: MarkdownTheme.TableStyle
    
    // MARK: - Init
    
    public init(tableData: TableData, tableStyle: MarkdownTheme.TableStyle) {
        self.tableData = tableData
        self.tableStyle = tableStyle
    }
}
