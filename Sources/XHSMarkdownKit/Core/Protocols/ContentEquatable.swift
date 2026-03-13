import Foundation

/// Fragment 内容协议。
/// 内容类型必须自行声明相等性语义，Core 不做任何具体类型分支。
public protocol FragmentContent {
    func isEqual(to other: any FragmentContent) -> Bool
    var attributedStringValue: NSAttributedString? { get }
}

public extension FragmentContent {
    var attributedStringValue: NSAttributedString? { nil }
}

extension NSAttributedString: FragmentContent {
    public func isEqual(to other: any FragmentContent) -> Bool {
        guard let rhs = other as? NSAttributedString else { return false }
        return isEqual(rhs)
    }

    public var attributedStringValue: NSAttributedString? { self }
}

public struct EmptyFragmentContent: FragmentContent, Hashable {
    public init() {}

    public func isEqual(to other: any FragmentContent) -> Bool {
        other is EmptyFragmentContent
    }
}
