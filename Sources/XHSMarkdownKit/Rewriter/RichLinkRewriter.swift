//
//  RichLinkRewriter.swift
//  XHSMarkdownKit
//
//  Created by 沃顿 on 2026-02-25.
//

import Foundation
import XYMarkdown

/// 蓝链模型协议
/// 宿主 App 的蓝链模型遵循此协议，XHSMarkdownKit 不直接依赖业务模型
public protocol RichLinkModel {
    /// 蓝链的显示文本
    var displayText: String { get }
    /// 蓝链的链接地址
    var linkURL: String { get }
    /// 蓝链匹配的原始 Markdown 链接 destination
    var httpLink: String? { get }
}

/// 蓝链 AST 改写器
///
/// 遍历 Document AST，将匹配蓝链模型的 Link 节点做标记/替换。
/// 利用 XYMarkdown 的 MarkupRewriter 协议，在 AST 级别改写，
/// 替代字符串匹配方式的蓝链处理。
public struct RichLinkRewriter: MarkupRewriter {
    
    private let richLinks: [RichLinkModel]
    private let urlToModel: [String: RichLinkModel]
    
    public init(richLinks: [RichLinkModel]) {
        self.richLinks = richLinks
        
        // 建立 URL 到模型的映射
        var map: [String: RichLinkModel] = [:]
        for model in richLinks {
            if let httpLink = model.httpLink {
                map[httpLink] = model
            }
            map[model.linkURL] = model
        }
        self.urlToModel = map
    }
    
    /// MarkupRewriter 协议：返回 nil 表示不修改，返回 Markup 表示替换
    public mutating func visitLink(_ link: Link) -> Markup? {
        guard let destination = link.destination,
              let matchedModel = urlToModel[destination] else {
            return nil  // 不是蓝链，保持原样
        }
        
        // 创建新的 Link，更新显示文本
        // 使用蓝链的显示文本替换原有内容
        let newText = Text(matchedModel.displayText)
        
        // 创建新的 Link 节点 - Link 接受 [RecurringInlineMarkup]
        let newChildren: [RecurringInlineMarkup] = [newText]
        let newLink = Link(destination: matchedModel.linkURL, newChildren)
        
        return newLink
    }
}

// MARK: - 简单蓝链模型实现

/// 简单蓝链模型（供测试和简单场景使用）
public struct SimpleRichLink: RichLinkModel {
    public let displayText: String
    public let linkURL: String
    public let httpLink: String?
    
    public init(displayText: String, linkURL: String, httpLink: String? = nil) {
        self.displayText = displayText
        self.linkURL = linkURL
        self.httpLink = httpLink
    }
}
