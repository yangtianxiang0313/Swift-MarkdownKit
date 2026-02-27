//
//  TextDisplayTarget.swift
//  XHSMarkdownKit
//

import UIKit

// MARK: - TextDisplayTarget

/// 可接收并显示富文本的 View（UILabel、UITextView）
/// 供 SubstringRevealStrategy、LayoutManagerRevealStrategy 等策略绑定目标
public protocol TextDisplayTarget: AnyObject {
    var displayAttributedText: NSAttributedString? { get set }
}

extension UILabel: TextDisplayTarget {
    public var displayAttributedText: NSAttributedString? {
        get { attributedText }
        set { attributedText = newValue }
    }
}

extension UITextView: TextDisplayTarget {
    public var displayAttributedText: NSAttributedString? {
        get { attributedText }
        set {
            attributedText = newValue ?? NSAttributedString()
            setNeedsDisplay()
            setNeedsLayout()
        }
    }
}
