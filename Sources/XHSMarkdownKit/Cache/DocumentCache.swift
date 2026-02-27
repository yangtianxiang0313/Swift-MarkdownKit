//
//  DocumentCache.swift
//  XHSMarkdownKit
//
//  Created by 沃顿 on 2026-02-25.
//

import Foundation
import XYMarkdown

/// Document 缓存
///
/// 相同的 Markdown 文本不重复解析，特别适合流式消息场景
/// （每次 append 文本后重新渲染，前面已解析的部分可以复用）
public final class DocumentCache {
    
    /// 默认缓存数量上限
    public static let defaultCountLimit = 100
    
    private let cache = NSCache<NSString, DocumentWrapper>()
    private let lock = NSLock()
    
    public init(countLimit: Int = defaultCountLimit) {
        cache.countLimit = countLimit
    }
    
    /// 获取或创建 Document
    public func document(for markdown: String) -> Document {
        let key = markdown as NSString
        
        lock.lock()
        defer { lock.unlock() }
        
        if let cached = cache.object(forKey: key) {
            return cached.document
        }
        
        let doc = Document(parsing: markdown, options: [.parseBlockDirectives])
        cache.setObject(DocumentWrapper(doc), forKey: key)
        return doc
    }
    
    /// 检查是否有缓存
    public func contains(_ markdown: String) -> Bool {
        let key = markdown as NSString
        lock.lock()
        defer { lock.unlock() }
        return cache.object(forKey: key) != nil
    }
    
    /// 清除所有缓存
    public func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAllObjects()
    }
    
    /// 设置缓存数量限制
    public var countLimit: Int {
        get { cache.countLimit }
        set { cache.countLimit = newValue }
    }
}

/// NSCache 要求值类型为 AnyObject
private final class DocumentWrapper: NSObject {
    let document: Document
    
    init(_ document: Document) {
        self.document = document
    }
}

// MARK: - 全局缓存实例

public extension DocumentCache {
    /// 共享缓存实例
    static let shared = DocumentCache()
}
