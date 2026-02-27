//
//  NSAttributedString+Markdown.swift
//  XHSMarkdownKit
//
//  Created by 沃顿 on 2026-02-25.
//

import UIKit

// MARK: - NSAttributedString 扩展

public extension NSAttributedString {
    
    /// 计算在指定宽度下的高度
    func height(maxWidth: CGFloat) -> CGFloat {
        let size = boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return ceil(size.height)
    }
    
    /// 计算在指定宽度下的尺寸
    func size(maxWidth: CGFloat) -> CGSize {
        let size = boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }
}

// MARK: - NSMutableAttributedString 扩展

public extension NSMutableAttributedString {
    
    /// 设置全文行高
    func setLineHeight(_ lineHeight: CGFloat) {
        guard length > 0 else { return }
        
        let range = NSRange(location: 0, length: length)
        enumerateAttribute(.paragraphStyle, in: range, options: []) { value, subRange, _ in
            let style = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle
                ?? NSMutableParagraphStyle()
            style.minimumLineHeight = lineHeight
            style.maximumLineHeight = lineHeight
            addAttribute(.paragraphStyle, value: style, range: subRange)
        }
    }
    
    /// 设置全文字间距
    func setKern(_ kern: CGFloat) {
        guard length > 0 else { return }
        addAttribute(.kern, value: kern, range: NSRange(location: 0, length: length))
    }
    
    /// 设置全文字体
    func setFont(_ font: UIFont) {
        guard length > 0 else { return }
        addAttribute(.font, value: font, range: NSRange(location: 0, length: length))
    }
    
    /// 设置全文颜色
    func setForegroundColor(_ color: UIColor) {
        guard length > 0 else { return }
        addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: length))
    }
    
    /// 移除指定范围的属性
    func removeAttribute(_ name: NSAttributedString.Key, in range: NSRange? = nil) {
        let effectiveRange = range ?? NSRange(location: 0, length: length)
        removeAttribute(name, range: effectiveRange)
    }
    
    /// 合并另一个 AttributedString 的属性
    func mergeAttributes(from source: NSAttributedString) {
        guard length > 0 && source.length > 0 else { return }
        
        let commonLength = min(length, source.length)
        source.enumerateAttributes(in: NSRange(location: 0, length: commonLength), options: []) { attrs, range, _ in
            for (key, value) in attrs {
                addAttribute(key, value: value, range: range)
            }
        }
    }
}

// MARK: - 段落样式便捷方法

public extension NSMutableParagraphStyle {
    
    /// 创建带行高的段落样式
    static func withLineHeight(_ lineHeight: CGFloat) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = lineHeight
        style.maximumLineHeight = lineHeight
        return style
    }
    
    /// 创建带缩进的段落样式
    static func withIndent(firstLine: CGFloat, head: CGFloat) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.firstLineHeadIndent = firstLine
        style.headIndent = head
        return style
    }
}

// MARK: - 属性字典便捷方法

public extension Dictionary where Key == NSAttributedString.Key, Value == Any {
    
    /// 创建正文属性
    static func body(
        font: UIFont,
        color: UIColor,
        lineHeight: CGFloat,
        kern: CGFloat = 0
    ) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight
        
        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        
        if kern != 0 {
            attrs[.kern] = kern
        }
        
        return attrs
    }
    
    /// 创建链接属性
    static func link(
        url: String,
        color: UIColor,
        underlineStyle: NSUnderlineStyle = []
    ) -> [NSAttributedString.Key: Any] {
        var attrs: [NSAttributedString.Key: Any] = [
            .link: url,
            .foregroundColor: color
        ]
        
        if underlineStyle != [] {
            attrs[.underlineStyle] = underlineStyle.rawValue
        }
        
        return attrs
    }
}
