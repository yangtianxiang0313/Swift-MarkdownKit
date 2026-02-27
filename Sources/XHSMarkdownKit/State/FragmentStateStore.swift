//
//  FragmentStateStore.swift
//  XHSMarkdownKit
//

import Foundation

// MARK: - FragmentStateStore

/// Fragment 外部状态存储
/// 唯一持有跨 render 周期的外部状态，供 Renderer 读取、供事件 Handler 更新
public final class FragmentStateStore {
    
    // MARK: - Storage
    
    /// [fragmentId: [stateType: state]]
    private var states: [String: [String: Any]] = [:]
    
    private let lock = NSLock()
    
    // MARK: - Callback
    
    /// 状态变更回调，参数为受影响的 fragmentId，`"*"` 表示全局刷新
    /// ContainerView 监听此回调并触发 render
    public var onStateChange: ((String) -> Void)?
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Read
    
    /// 获取指定 Fragment 的状态
    /// 若未设置则返回该类型的 defaultState
    public func getState<S: FragmentState>(_ type: S.Type, for fragmentId: String) -> S {
        lock.lock()
        defer { lock.unlock() }
        
        if let stored = states[fragmentId]?[S.stateType] as? S {
            return stored
        }
        return S.defaultState
    }
    
    // MARK: - Write
    
    /// 更新指定 Fragment 的状态
    /// - Parameters:
    ///   - state: 新状态
    ///   - fragmentId: Fragment ID
    ///   - triggerRender: 是否触发 onStateChange 回调
    public func updateState<S: FragmentState>(
        _ state: S,
        for fragmentId: String,
        triggerRender: Bool = true
    ) {
        lock.lock()
        if states[fragmentId] == nil {
            states[fragmentId] = [:]
        }
        states[fragmentId]?[S.stateType] = state
        lock.unlock()
        
        if triggerRender {
            onStateChange?(fragmentId)
        }
    }
    
    /// 批量更新（避免多次触发渲染）
    public func batchUpdate(_ updates: () -> Void) {
        let originalCallback = onStateChange
        onStateChange = nil
        updates()
        onStateChange = originalCallback
        onStateChange?("*")
    }
    
    // MARK: - Cleanup
    
    /// 清理指定 Fragment 的状态
    public func clearState(for fragmentId: String) {
        lock.lock()
        states.removeValue(forKey: fragmentId)
        lock.unlock()
    }
    
    /// 清理已不存在 Fragment 的状态（GC）
    public func gc(existingIds: Set<String>) {
        lock.lock()
        states = states.filter { existingIds.contains($0.key) }
        lock.unlock()
    }
}
