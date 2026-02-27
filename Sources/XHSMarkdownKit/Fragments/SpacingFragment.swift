import Foundation
import UIKit

// MARK: - SpacingFragment

/// 间距片段
/// 表示两个内容片段之间的垂直间距（无需 RenderContext 上下文字段）
public struct SpacingFragment: RenderFragment, FragmentViewFactory, FragmentContextRequirements {
    
    // MARK: - RenderFragment
    
    public let fragmentId: String
    public let nodeType: MarkdownNodeType = .spacing
    
    // MARK: - Content
    
    /// 间距高度
    public let height: CGFloat
    
    // MARK: - FragmentViewFactory
    
    public var reuseIdentifier: ReuseIdentifier { .spacing }
    public var estimatedSize: CGSize { CGSize(width: 0, height: height) }
    public var context: FragmentContext { .init() }
    
    public func makeView() -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }
    
    public func configure(_ view: UIView, theme: MarkdownTheme) {
        // 无需配置
    }
    
    // MARK: - Initialization
    
    public init(
        fragmentId: String,
        height: CGFloat
    ) {
        self.fragmentId = fragmentId
        self.height = height
    }
}

// MARK: - FragmentContextRequirements

extension SpacingFragment {
    public static var contextKeys: Set<FragmentContextKey> { [] }
}
