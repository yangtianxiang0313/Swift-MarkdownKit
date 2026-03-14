import UIKit
#if canImport(XHSMarkdownCore)
import XHSMarkdownCore
#endif

public protocol SceneContainerView: AnyObject {
    var sceneContentStackView: UIStackView { get }
    var sceneContentWidthReduction: CGFloat { get }
}

public protocol SceneComponent {
    var reuseIdentifier: String { get }
    var revealUnitCount: Int { get }

    func makeView() -> UIView
    func configure(view: UIView, maxWidth: CGFloat)
    func reveal(view: UIView, displayedUnits: Int)
    func isContentEqual(to other: any SceneComponent) -> Bool
}

public struct TextSceneComponent: SceneComponent {
    public let attributedText: NSAttributedString
    public let numberOfLines: Int

    public init(attributedText: NSAttributedString, numberOfLines: Int = 0) {
        self.attributedText = attributedText
        self.numberOfLines = numberOfLines
    }

    public var reuseIdentifier: String { "scene.text" }
    public var revealUnitCount: Int { attributedText.string.count }

    public func makeView() -> UIView {
        let label = UILabel()
        label.numberOfLines = numberOfLines
        return label
    }

    public func configure(view: UIView, maxWidth: CGFloat) {
        guard let label = view as? UILabel else { return }
        label.numberOfLines = numberOfLines
        label.preferredMaxLayoutWidth = maxWidth
        label.attributedText = attributedText
    }

    public func reveal(view: UIView, displayedUnits: Int) {
        guard let label = view as? UILabel else { return }
        let text = attributedText.string
        let clamped = max(0, min(displayedUnits, text.count))
        if clamped <= 0 {
            label.attributedText = NSAttributedString(string: "")
            return
        }
        label.attributedText = attributedText.attributedSubstring(
            from: NSRange(location: 0, length: clamped)
        )
    }

    public func isContentEqual(to other: any SceneComponent) -> Bool {
        guard let rhs = other as? TextSceneComponent else { return false }
        return attributedText.isEqual(to: rhs.attributedText) && numberOfLines == rhs.numberOfLines
    }
}

public struct RuleSceneComponent: SceneComponent {
    public let color: UIColor
    public let height: CGFloat
    public let verticalPadding: CGFloat

    public init(color: UIColor, height: CGFloat, verticalPadding: CGFloat = 0) {
        self.color = color
        self.height = max(1, height)
        self.verticalPadding = max(0, verticalPadding)
    }

    public var reuseIdentifier: String { "scene.rule" }
    public var revealUnitCount: Int { 1 }

    public func makeView() -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: height + verticalPadding * 2)
        ])
        let lineView = UIView()
        lineView.tag = 1001
        view.addSubview(lineView)
        return view
    }

    public func configure(view: UIView, maxWidth: CGFloat) {
        let lineView: UIView
        if let existing = view.viewWithTag(1001) {
            lineView = existing
        } else {
            lineView = UIView()
            lineView.tag = 1001
            view.addSubview(lineView)
        }
        view.backgroundColor = .clear
        lineView.backgroundColor = color
        lineView.frame = CGRect(
            x: 0,
            y: verticalPadding,
            width: view.bounds.width,
            height: height
        )
    }

    public func reveal(view: UIView, displayedUnits: Int) {}

    public func isContentEqual(to other: any SceneComponent) -> Bool {
        guard let rhs = other as? RuleSceneComponent else { return false }
        return color == rhs.color && height == rhs.height && verticalPadding == rhs.verticalPadding
    }
}

public struct CustomViewSceneComponent: SceneComponent {
    public let reuseIdentifier: String
    public let revealUnitCount: Int
    public let signature: String
    private let make: () -> UIView
    private let configureBlock: (UIView, CGFloat) -> Void
    private let revealBlock: ((UIView, Int) -> Void)?

    public init(
        reuseIdentifier: String,
        revealUnitCount: Int = 1,
        signature: String,
        make: @escaping () -> UIView,
        configure: @escaping (UIView, CGFloat) -> Void,
        reveal: ((UIView, Int) -> Void)? = nil
    ) {
        self.reuseIdentifier = reuseIdentifier
        self.revealUnitCount = max(1, revealUnitCount)
        self.signature = signature
        self.make = make
        self.configureBlock = configure
        self.revealBlock = reveal
    }

    public func makeView() -> UIView {
        make()
    }

    public func configure(view: UIView, maxWidth: CGFloat) {
        configureBlock(view, maxWidth)
    }

    public func reveal(view: UIView, displayedUnits: Int) {
        revealBlock?(view, displayedUnits)
    }

    public func isContentEqual(to other: any SceneComponent) -> Bool {
        guard let rhs = other as? CustomViewSceneComponent else { return false }
        return reuseIdentifier == rhs.reuseIdentifier && revealUnitCount == rhs.revealUnitCount && signature == rhs.signature
    }
}

public struct RenderScene: Equatable {
    public struct Node: Equatable {
        public var id: String
        public var kind: String
        public var component: (any SceneComponent)?
        public var children: [Node]
        public var spacingAfter: CGFloat
        public var metadata: [String: MarkdownContract.Value]

        public init(
            id: String,
            kind: String,
            component: (any SceneComponent)? = nil,
            children: [Node] = [],
            spacingAfter: CGFloat = 0,
            metadata: [String: MarkdownContract.Value] = [:]
        ) {
            self.id = id
            self.kind = kind
            self.component = component
            self.children = children
            self.spacingAfter = spacingAfter
            self.metadata = metadata
        }

        public static func == (lhs: Node, rhs: Node) -> Bool {
            guard lhs.id == rhs.id,
                  lhs.kind == rhs.kind,
                  lhs.children == rhs.children,
                  lhs.spacingAfter == rhs.spacingAfter,
                  lhs.metadata == rhs.metadata else {
                return false
            }

            switch (lhs.component, rhs.component) {
            case (nil, nil):
                return true
            case let (l?, r?):
                return l.isContentEqual(to: r)
            default:
                return false
            }
        }
    }

    public var documentId: String
    public var nodes: [Node]
    public var metadata: [String: MarkdownContract.Value]

    public init(documentId: String, nodes: [Node], metadata: [String: MarkdownContract.Value] = [:]) {
        self.documentId = documentId
        self.nodes = nodes
        self.metadata = metadata
    }

    public var entityIDs: [String] {
        flattenRenderableNodes().map(\.id)
    }

    public func flattenRenderableNodes() -> [Node] {
        var result: [Node] = []

        func walk(_ node: Node) {
            if node.component != nil {
                result.append(node)
            }
            for child in node.children {
                walk(child)
            }
        }

        for node in nodes {
            walk(node)
        }

        return result
    }

    public func componentNodeIDs() -> Set<String> {
        var ids: Set<String> = []

        func walk(_ node: Node) {
            if node.component != nil {
                ids.insert(node.id)
            }
            for child in node.children {
                walk(child)
            }
        }

        for node in nodes {
            walk(node)
        }

        return ids
    }

    public static func empty(documentId: String) -> RenderScene {
        RenderScene(documentId: documentId, nodes: [])
    }
}
