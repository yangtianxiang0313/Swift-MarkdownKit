import Foundation
import UIKit

// MARK: - ViewFragment

/// 视图片段
/// 包含自定义 View 的创建和配置信息（方案 1：Fragment 统一携带 ViewFactory）
public struct ViewFragment: RenderFragment, FragmentViewFactory, FragmentContextRequirements {
    
    // MARK: - RenderFragment
    
    public let fragmentId: String
    public let nodeType: MarkdownNodeType
    
    // MARK: - FragmentViewFactory
    
    /// 复用标识符
    public let reuseIdentifier: ReuseIdentifier
    
    /// 预估尺寸（用于初始布局）
    public let estimatedSize: CGSize

    /// 上下文信息（indent、blockQuoteDepth 等）
    public let context: FragmentContext

    /// 内容数据（传递给 View 用于更新）
    public let content: Any

    /// 按动画进度计算高度的提供者（可选）
    private let _heightProvider: FragmentHeightProvider?

    /// 创建新 View 的工厂方法
    private let _makeView: () -> UIView

    /// 内部配置闭包（view, content, theme）
    private let _configure: (UIView, Any, MarkdownTheme) -> Void

    // MARK: - FragmentViewFactory

    public func makeView() -> UIView {
        _makeView()
    }

    public func configure(_ view: UIView, theme: MarkdownTheme) {
        _configure(view, content, theme)
    }

    public func estimatedHeight(
        atDisplayedLength displayedLength: Int,
        maxWidth: CGFloat,
        theme: MarkdownTheme
    ) -> CGFloat {
        _heightProvider?.estimatedHeight(atDisplayedLength: displayedLength, maxWidth: maxWidth, theme: theme) ?? estimatedSize.height
    }

    // MARK: - Initialization

    public init(
        fragmentId: String,
        nodeType: MarkdownNodeType,
        reuseIdentifier: ReuseIdentifier,
        estimatedSize: CGSize = .zero,
        context: FragmentContext = .init(),
        content: Any,
        heightProvider: FragmentHeightProvider? = nil,
        makeView: @escaping () -> UIView,
        configure: @escaping (UIView, Any, MarkdownTheme) -> Void
    ) {
        self.fragmentId = fragmentId
        self.nodeType = nodeType
        self.reuseIdentifier = reuseIdentifier
        self.estimatedSize = estimatedSize
        self.context = context
        self.content = content
        self._heightProvider = heightProvider
        self._makeView = makeView
        self._configure = configure
    }
}

// MARK: - FragmentContextRequirements

extension ViewFragment {
    public static var contextKeys: Set<FragmentContextKey> { [.indent] }
}

// MARK: - Typed ViewFragment

/// 类型安全的 ViewFragment 构建器
public extension ViewFragment {

    /// 创建类型安全的 ViewFragment
    static func typed<V: UIView, C>(
        fragmentId: String,
        nodeType: MarkdownNodeType,
        reuseIdentifier: ReuseIdentifier,
        estimatedSize: CGSize = .zero,
        context: FragmentContext = .init(),
        content: C,
        heightProvider: FragmentHeightProvider? = nil,
        makeView: @escaping () -> V,
        configure: @escaping (V, C, MarkdownTheme) -> Void
    ) -> ViewFragment {
        ViewFragment(
            fragmentId: fragmentId,
            nodeType: nodeType,
            reuseIdentifier: reuseIdentifier,
            estimatedSize: estimatedSize,
            context: context,
            content: content,
            heightProvider: heightProvider,
            makeView: makeView,
            configure: { view, anyContent, theme in
                guard let typedView = view as? V,
                      let typedContent = anyContent as? C else { return }
                configure(typedView, typedContent, theme)
            }
        )
    }
}
