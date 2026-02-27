//
//  MarkdownPreprocessor.swift
//  XHSMarkdownKit
//
//  Created by 沃顿 on 2026-02-25.
//

import Foundation

// MARK: - InlineDelimiter

/// 行内定界符（从长到短匹配，避免 ** 和 * 冲突）
public enum InlineDelimiter: String, CaseIterable {
    case boldItalic = "***"
    case bold = "**"
    case strikethrough = "~~"
    case underscoreBold = "__"
    case underscore = "_"
    case asterisk = "*"
    case backtick = "`"
    
    public static let all: [String] = InlineDelimiter.allCases.map(\.rawValue)
}

// MARK: - CodeFence

/// 围栏代码块标记
public enum CodeFence: String {
    case backtick = "```"
    case tilde = "~~~"
}

// MARK: - MarkdownPreprocessor

/// Markdown 未闭合标记预处理器
///
/// 在 cmark 解析前运行，扫描文本尾部的未闭合行内标记和围栏代码块，
/// 自动追加闭合标记。不修改原始文本，只影响解析输入。
public struct MarkdownPreprocessor {
    
    /// 行分隔符
    public static let lineSeparator = "\n"
    /// 段落分隔符
    public static let paragraphSeparator = "\n\n"
    
    /// 对流式文本进行预闭合处理
    /// - Parameter text: 原始 Markdown 文本（可能未闭合）
    /// - Returns: 预闭合后的文本（供解析用，不回写到 buffer）
    public static func preclose(_ text: String) -> String {
        var result = text
        
        // ── 围栏代码块（优先级最高，代码块内的行内标记不处理）──
        if let fence = unclosedCodeFence(text) {
            result += "\(MarkdownPreprocessor.lineSeparator)\(fence)"
            return result  // 代码块内不做行内预闭合
        }
        
        // ── 行内标记（从长到短匹配，避免 ** 和 * 冲突）──
        for delimiter in InlineDelimiter.all {
            if hasUnclosedDelimiter(result, delimiter) {
                result += delimiter
            }
        }
        
        return result
    }
    
    // MARK: - 私有方法
    
    /// 检测未闭合的围栏代码块，返回应使用的闭合标记
    private static func unclosedCodeFence(_ text: String) -> String? {
        var state = FenceState.none
        
        let lines = text.components(separatedBy: lineSeparator)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            switch state {
            case .none:
                if trimmed.hasPrefix(CodeFence.backtick.rawValue) {
                    state = .inBacktickFence
                } else if trimmed.hasPrefix(CodeFence.tilde.rawValue) {
                    state = .inTildeFence
                }
                
            case .inBacktickFence:
                if trimmed.hasPrefix(CodeFence.backtick.rawValue) {
                    state = .none
                }
                
            case .inTildeFence:
                if trimmed.hasPrefix(CodeFence.tilde.rawValue) {
                    state = .none
                }
            }
        }
        
        switch state {
        case .none:
            return nil
        case .inBacktickFence:
            return CodeFence.backtick.rawValue
        case .inTildeFence:
            return CodeFence.tilde.rawValue
        }
    }
    
    /// 围栏代码块状态
    private enum FenceState {
        case none
        case inBacktickFence
        case inTildeFence
    }
    
    /// 检测未闭合的行内定界符
    private static func hasUnclosedDelimiter(_ text: String, _ delimiter: String) -> Bool {
        // 取最后一个块级元素的文本（不跨段落检测）
        let lastBlock = text.components(separatedBy: paragraphSeparator).last ?? text
        
        // 跳过空内容
        guard !lastBlock.isEmpty else { return false }
        
        // 特殊处理：如果以定界符结尾，可能是已完成的标记
        if lastBlock.hasSuffix(delimiter) {
            // 检查是否是成对的
            let withoutSuffix = String(lastBlock.dropLast(delimiter.count))
            return hasUnclosedDelimiter(withoutSuffix, delimiter)
        }
        
        // 统计定界符出现次数
        var count = 0
        var searchRange = lastBlock.startIndex..<lastBlock.endIndex
        
        while let range = lastBlock.range(of: delimiter, range: searchRange) {
            // 检查是否被转义
            let index = range.lowerBound
            if index > lastBlock.startIndex {
                let prevIndex = lastBlock.index(before: index)
                if lastBlock[prevIndex] == "\\" {
                    // 被转义，跳过
                    searchRange = range.upperBound..<lastBlock.endIndex
                    continue
                }
            }
            
            count += 1
            searchRange = range.upperBound..<lastBlock.endIndex
        }
        
        // 奇数 = 未闭合
        return count % 2 == 1
    }
}

// MARK: - 便捷扩展

public extension String {
    /// 预闭合 Markdown 未闭合标记
    var markdownPreclosed: String {
        MarkdownPreprocessor.preclose(self)
    }
}
