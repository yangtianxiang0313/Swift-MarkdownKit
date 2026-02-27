//
//  RewriterPipeline.swift
//  XHSMarkdownKit
//
//  Created by 沃顿 on 2026-02-25.
//

import Foundation
import XYMarkdown

/// 类型擦除的 MarkupRewriter 包装
public struct AnyMarkupRewriter {
    private let _rewrite: (Document) -> Document
    
    public init<R: MarkupRewriter>(_ rewriter: R) {
        var r = rewriter
        _rewrite = { document in
            (r.visit(document) as? Document) ?? document
        }
    }
    
    /// 重写文档
    public func rewrite(_ document: Document) -> Document {
        _rewrite(document)
    }
}

/// Rewriter 管线：按顺序串联执行多个 AST 改写器
public struct RewriterPipeline {
    
    private let rewriters: [AnyMarkupRewriter]
    
    public init(rewriters: [AnyMarkupRewriter]) {
        self.rewriters = rewriters
    }
    
    /// 便捷构造：直接传入 MarkupRewriter 数组
    public init<R: MarkupRewriter>(_ rewriters: [R]) {
        self.rewriters = rewriters.map { AnyMarkupRewriter($0) }
    }
    
    /// 按顺序执行所有改写器
    public func rewrite(_ document: Document) -> Document {
        rewriters.reduce(document) { doc, rewriter in
            rewriter.rewrite(doc)
        }
    }
    
    /// 添加新的改写器
    public func adding(_ rewriter: AnyMarkupRewriter) -> RewriterPipeline {
        RewriterPipeline(rewriters: rewriters + [rewriter])
    }
    
    /// 空管线
    public static let empty = RewriterPipeline(rewriters: [])
}

// MARK: - 便捷构造

public extension RewriterPipeline {
    /// 创建包含蓝链改写的管线
    static func richLink(_ models: [RichLinkModel]) -> RewriterPipeline {
        let rewriter = RichLinkRewriter(richLinks: models)
        return RewriterPipeline(rewriters: [AnyMarkupRewriter(rewriter)])
    }
}
