//
//  TextRevealStrategy.swift
//  XHSMarkdownKit
//

import Foundation
import UIKit

// MARK: - TextRevealStrategy

/// 文本逐字揭示策略协议
/// 不绑定 NSTextStorage，架构只依赖此协议
public protocol TextRevealStrategy: AnyObject {
    var displayedLength: Int { get }
    var totalLength: Int { get }
    func reveal(upTo length: Int)
    func updateContent(_ new: NSAttributedString) -> ContentUpdateResult
}

// MARK: - SubstringRevealStrategy

/// Substring 揭示策略
/// 使用 attributedSubstring 写回 targetView
public final class SubstringRevealStrategy: TextRevealStrategy {
    private weak var targetView: TextDisplayTarget?
    private var _fullText: NSAttributedString
    private var _displayedLength: Int
    private var _previousPlainText: String

    public var displayedLength: Int { _displayedLength }
    public var totalLength: Int { _fullText.length }

    public init(targetView: TextDisplayTarget) {
        self.targetView = targetView
        self._fullText = NSAttributedString()
        self._displayedLength = 0
        self._previousPlainText = ""
    }

    public func reveal(upTo length: Int) {
        let len = _fullText.length
        let safeLen = min(max(0, length), len)
        _displayedLength = safeLen

        guard let target = targetView else { return }
        if safeLen == 0 {
            target.displayAttributedText = nil
        } else if safeLen >= len {
            target.displayAttributedText = _fullText
        } else {
            target.displayAttributedText = _fullText.attributedSubstring(from: NSRange(location: 0, length: safeLen))
        }
    }

    public func updateContent(_ new: NSAttributedString) -> ContentUpdateResult {
        let result = ContentChangeAnalyzer.analyze(oldPlain: _previousPlainText, new: new)
        _fullText = new
        _previousPlainText = new.string

        switch result.type {
        case .unchanged:
            break
        case .append, .truncated:
            _displayedLength = result.currentLength
        case .modified(let prefixLen):
            _displayedLength = min(_displayedLength, prefixLen)
        }

        return result
    }
}
