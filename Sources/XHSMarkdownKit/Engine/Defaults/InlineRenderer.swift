import Foundation
import UIKit
import XYMarkdown

// MARK: - InlineRenderer

/// 行内元素渲染器
/// 将行内元素转换为 NSAttributedString
public enum InlineRenderer {
    
    /// 渲染节点的所有行内子元素
    /// - Parameters:
    ///   - node: 包含行内元素的节点
    ///   - context: 渲染上下文
    ///   - baseFont: 基础字体（默认使用主题的 bodyFont）
    ///   - baseColor: 基础颜色（默认使用主题的 bodyColor）
    ///   - lineHeight: 行高（默认使用主题的 bodyLineHeight）
    /// - Returns: 渲染后的富文本
    public static func renderInlines(
        node: Markup,
        context: RenderContext,
        baseFont: UIFont? = nil,
        baseColor: UIColor? = nil,
        lineHeight: CGFloat? = nil
    ) -> NSAttributedString {
        let theme = context.theme
        let font = baseFont ?? theme.body.font
        let color = baseColor ?? theme.body.color
        let height = lineHeight ?? theme.body.lineHeight
        
        let result = NSMutableAttributedString()
        
        for child in node.children {
            result.append(renderInlineNode(child, context: context, font: font, color: color))
        }
        
        // 应用段落样式
        if result.length > 0 {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.minimumLineHeight = height
            paragraphStyle.maximumLineHeight = height
            paragraphStyle.lineSpacing = 0
            
            result.addAttribute(
                .paragraphStyle,
                value: paragraphStyle,
                range: NSRange(location: 0, length: result.length)
            )
        }
        
        return result
    }
    
    /// 渲染单个行内节点
    private static func renderInlineNode(
        _ node: Markup,
        context: RenderContext,
        font: UIFont,
        color: UIColor
    ) -> NSAttributedString {
        let theme = context.theme
        
        switch node {
        case let text as Text:
            return NSAttributedString(
                string: text.string,
                attributes: [
                    .font: font,
                    .foregroundColor: color,
                    .kern: theme.body.letterSpacing
                ]
            )
            
        case let strong as Strong:
            let boldFont = font.bold
            #if DEBUG
            print("[InlineRenderer] Strong: font=\(font.fontName) → bold=\(boldFont.fontName)")
            #endif
            let result = NSMutableAttributedString()
            for child in strong.children {
                result.append(renderInlineNode(child, context: context, font: boldFont, color: color))
            }
            return result
            
        case let emphasis as Emphasis:
            let result = NSMutableAttributedString()
            let emphasisFont: UIFont
            let emphasisColor = color
            
            switch theme.emphasis.type {
            case .italic:
                emphasisFont = font.italic
            case .highlight:
                emphasisFont = font
            case .both:
                emphasisFont = font.italic
            }
            
            for child in emphasis.children {
                result.append(renderInlineNode(child, context: context, font: emphasisFont, color: emphasisColor))
            }
            
            // 添加高亮背景
            if theme.emphasis.type == .highlight || theme.emphasis.type == .both {
                result.addAttribute(
                    .backgroundColor,
                    value: theme.emphasis.highlightColor,
                    range: NSRange(location: 0, length: result.length)
                )
            }
            
            return result
            
        case let code as InlineCode:
            return NSAttributedString(
                string: code.code,
                attributes: [
                    .font: theme.code.font,
                    .foregroundColor: theme.code.inlineColor,
                    .kern: theme.code.letterSpacing
                ]
            )
            
        case let link as Link:
            let result = NSMutableAttributedString()
            for child in link.children {
                result.append(renderInlineNode(child, context: context, font: font, color: theme.link.color))
            }
            
            if let destination = link.destination {
                result.addAttribute(
                    .link,
                    value: destination,
                    range: NSRange(location: 0, length: result.length)
                )
            }
            
            if !theme.link.underlineStyle.isEmpty {
                result.addAttribute(
                    .underlineStyle,
                    value: theme.link.underlineStyle.rawValue,
                    range: NSRange(location: 0, length: result.length)
                )
            }
            
            return result
            
        case let strikethrough as Strikethrough:
            let result = NSMutableAttributedString()
            for child in strikethrough.children {
                result.append(renderInlineNode(child, context: context, font: font, color: color))
            }
            
            result.addAttribute(
                .strikethroughStyle,
                value: theme.strikethrough.style.rawValue,
                range: NSRange(location: 0, length: result.length)
            )
            
            if let strikeColor = theme.strikethrough.color {
                result.addAttribute(
                    .strikethroughColor,
                    value: strikeColor,
                    range: NSRange(location: 0, length: result.length)
                )
            }
            
            return result
            
        case is LineBreak:
            return NSAttributedString(string: "\n")
            
        case is SoftBreak:
            return NSAttributedString(string: " ")
            
        default:
            // 尝试递归渲染子节点
            let result = NSMutableAttributedString()
            for child in node.children {
                result.append(renderInlineNode(child, context: context, font: font, color: color))
            }
            return result
        }
    }
}
