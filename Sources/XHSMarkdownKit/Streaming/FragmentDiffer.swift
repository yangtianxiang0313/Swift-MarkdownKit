//
//  FragmentDiffer.swift
//  XHSMarkdownKit
//
//  Created by 沃顿 on 2026-02-25.
//

import UIKit

// MARK: - FragmentChange

/// Fragment 变化类型
public enum FragmentChange {
    /// 插入新 Fragment
    case insert(fragment: RenderFragment, at: Int)
    
    /// 更新现有 Fragment
    case update(old: RenderFragment, new: RenderFragment, at: Int)
    
    /// 删除 Fragment
    case delete(fragment: RenderFragment, at: Int)
    
    /// 获取关联的 Fragment ID
    public var fragmentId: String {
        switch self {
        case .insert(let fragment, _):
            return fragment.fragmentId
        case .update(_, let new, _):
            return new.fragmentId
        case .delete(let fragment, _):
            return fragment.fragmentId
        }
    }
    
    /// 获取变化位置
    public var index: Int {
        switch self {
        case .insert(_, let index): return index
        case .update(_, _, let index): return index
        case .delete(_, let index): return index
        }
    }
}

// MARK: - FragmentDiffer

/// Fragment 差异比对器
///
/// 流式场景的 diff 特点：
/// - 大部分情况只有"最后一个 fragment update + 可能 append 新 fragment"
/// - replace/remove 场景可能涉及中间 fragment 的 update/delete
/// - Fragment 数量通常 < 50，线性比对即可
public struct FragmentDiffer {
    
    /// 计算新旧 Fragment 序列的差异
    public static func diff(
        old: [RenderFragment],
        new: [RenderFragment]
    ) -> [FragmentChange] {
        var changes: [FragmentChange] = []
        
        let oldMap = Dictionary(uniqueKeysWithValues: old.enumerated().map { ($1.fragmentId, $0) })
        var matchedOldIndices = Set<Int>()
        
        // 遍历新序列，匹配旧序列
        for (newIndex, newFragment) in new.enumerated() {
            if let oldIndex = oldMap[newFragment.fragmentId] {
                matchedOldIndices.insert(oldIndex)
                // 存在于旧序列 → 检查内容是否变化
                let oldFragment = old[oldIndex]
                if !fragmentContentEqual(oldFragment, newFragment) {
                    changes.append(.update(old: oldFragment, new: newFragment, at: newIndex))
                }
            } else {
                // 不存在于旧序列 → 新增
                changes.append(.insert(fragment: newFragment, at: newIndex))
            }
        }
        
        // 旧序列中未匹配的 → 删除
        for (oldIndex, oldFragment) in old.enumerated() where !matchedOldIndices.contains(oldIndex) {
            changes.append(.delete(fragment: oldFragment, at: oldIndex))
        }
        
        return changes
    }
    
    /// 比较两个 Fragment 的内容是否相同
    private static func fragmentContentEqual(
        _ lhs: RenderFragment,
        _ rhs: RenderFragment
    ) -> Bool {
        switch (lhs, rhs) {
        case let (l as TextFragment, r as TextFragment):
            return l.attributedString.isEqual(to: r.attributedString)
        case let (l as ViewFragment, r as ViewFragment):
            // ViewFragment 比较 reuseIdentifier 和 content 类型
            // 内容可能变化，所以总是认为需要更新
            return false
        case let (l as SpacingFragment, r as SpacingFragment):
            return l.height == r.height
        default:
            return false
        }
    }
}

// MARK: - StreamingFragmentDiffer

/// 流式特化的 Diff 算法
///
/// 利用流式场景的特点：
/// 1. 大部分情况只有尾部 append（快速路径）
/// 2. 偶尔有中间 update（需要检测）
/// 3. 很少有 delete（需要完整 diff）
public struct StreamingFragmentDiffer {
    
    /// 快速路径：检测是否只有尾部 append 和最后一个 update
    /// 返回 nil 表示需要全量 diff
    public static func tryFastAppendDiff(
        old: [RenderFragment],
        new: [RenderFragment]
    ) -> [FragmentChange]? {
        // 快速检查：新序列长度 < 旧序列长度 → 不是纯 append，需要全量 diff
        guard new.count >= old.count else { return nil }
        
        // 检查前 old.count 个 fragment 是否 ID 相同
        for i in 0..<old.count {
            if old[i].fragmentId != new[i].fragmentId {
                // 前缀不同 → 可能有 replace/delete，需要全量 diff
                return nil
            }
        }
        
        // 检查有变化的 fragment
        var changes: [FragmentChange] = []
        
        for i in 0..<old.count {
            let oldFragment = old[i]
            let newFragment = new[i]
            
            if !fragmentContentEqual(oldFragment, newFragment) {
                changes.append(.update(old: oldFragment, new: newFragment, at: i))
            }
        }
        
        // 新增的 fragment
        for i in old.count..<new.count {
            changes.append(.insert(fragment: new[i], at: i))
        }
        
        return changes
    }
    
    /// 完整 diff（当快速路径失败时）
    public static func fullDiff(
        old: [RenderFragment],
        new: [RenderFragment]
    ) -> [FragmentChange] {
        FragmentDiffer.diff(old: old, new: new)
    }
    
    /// 统一入口：自动选择快速路径或完整 diff
    public static func diff(
        old: [RenderFragment],
        new: [RenderFragment]
    ) -> [FragmentChange] {
        if let fastChanges = tryFastAppendDiff(old: old, new: new) {
            return fastChanges  // 快速路径
        }
        return fullDiff(old: old, new: new)  // 完整 diff
    }
    
    // MARK: - 私有方法
    
    private static func fragmentContentEqual(
        _ lhs: RenderFragment,
        _ rhs: RenderFragment
    ) -> Bool {
        switch (lhs, rhs) {
        case let (l as TextFragment, r as TextFragment):
            return l.attributedString.isEqual(to: r.attributedString)
        case let (l as ViewFragment, r as ViewFragment):
            // ViewFragment 的内容总是需要检查更新
            return false
        case let (l as SpacingFragment, r as SpacingFragment):
            return l.height == r.height
        default:
            return false
        }
    }
}
