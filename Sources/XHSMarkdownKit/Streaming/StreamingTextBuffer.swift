//
//  StreamingTextBuffer.swift
//  XHSMarkdownKit
//
//  Created by 沃顿 on 2026-02-25.
//

import UIKit

/// 流式文本缓冲器
///
/// 管理 SSE chunk 的累积，支持 append / replace / remove 三种操作。
/// 按节流频率触发下游解析。
public final class StreamingTextBuffer {
    
    /// 当前完整文本
    public private(set) var text: String = ""
    
    /// 脏标记 — 自上次触发解析后文本是否变化
    private var isDirty: Bool = false
    
    /// 节流 timer（合并高频 chunk）
    private var displayLink: CADisplayLink?
    
    /// 下游回调：文本变化时触发解析
    public var onTextChanged: ((String) -> Void)?
    
    /// 流式结束回调
    public var onFinished: (() -> Void)?
    
    /// 是否正在流式中
    public private(set) var isStreaming: Bool = false
    
    public init() {}
    
    deinit {
        displayLink?.invalidate()
    }
    
    // MARK: - 数据操作（业务层调用）
    
    /// 开始流式
    public func start() {
        text = ""
        isDirty = false
        isStreaming = true
    }
    
    /// 追加文本（最常见的流式场景）
    public func append(_ chunk: String) {
        text.append(chunk)
        markDirty()
    }
    
    /// 替换指定范围（AI 修改前面的回答）
    public func replace(range: Range<String.Index>, with newText: String) {
        text.replaceSubrange(range, with: newText)
        markDirty()
    }
    
    /// 删除指定范围
    public func remove(range: Range<String.Index>) {
        text.removeSubrange(range)
        markDirty()
    }
    
    /// 全量替换（整段重写）
    public func setText(_ newText: String) {
        text = newText
        markDirty()
    }
    
    // MARK: - 节流
    
    private func markDirty() {
        isDirty = true
        isStreaming = true
        startDisplayLinkIfNeeded()
    }
    
    private func startDisplayLinkIfNeeded() {
        guard displayLink == nil else { return }
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFire))
        // preferredFrameRateRange: 30-60fps，系统自适应
        if #available(iOS 15.0, *) {
            displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60)
        }
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func displayLinkFire() {
        guard isDirty else { return }
        isDirty = false
        onTextChanged?(text)
    }
    
    /// 流式结束，立即 flush + 停止 timer
    public func finish() {
        displayLink?.invalidate()
        displayLink = nil
        
        if isDirty {
            isDirty = false
            onTextChanged?(text)
        }
        
        isStreaming = false
        onFinished?()
    }
    
    /// 重置缓冲区
    public func reset() {
        displayLink?.invalidate()
        displayLink = nil
        text = ""
        isDirty = false
        isStreaming = false
    }
}
