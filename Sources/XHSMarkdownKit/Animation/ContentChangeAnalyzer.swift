//
//  ContentChangeAnalyzer.swift
//  XHSMarkdownKit
//

import Foundation
import UIKit

// MARK: - ContentChangeAnalyzer

/// 内容变化分析器
/// 比较旧纯文本与新富文本，返回变化类型
public enum ContentChangeAnalyzer {

    public static func analyze(
        oldPlain: String,
        new: NSAttributedString
    ) -> ContentUpdateResult {
        let newPlainText = new.string
        let oldLength = (oldPlain as NSString).length
        let newLength = newPlainText.count

        if oldPlain == newPlainText {
            return .unchanged(length: newLength)
        }

        let commonPrefixLength = zip(oldPlain, newPlainText)
            .prefix(while: { $0 == $1 })
            .count

        if commonPrefixLength == oldLength {
            return .append(addedCount: newLength - oldLength, previousLength: oldLength)
        } else if newLength < oldLength, commonPrefixLength == newLength {
            return .truncated(newLength: newLength, previousLength: oldLength)
        } else {
            return .modified(
                unchangedPrefixLength: commonPrefixLength,
                previousLength: oldLength,
                currentLength: newLength
            )
        }
    }
}
