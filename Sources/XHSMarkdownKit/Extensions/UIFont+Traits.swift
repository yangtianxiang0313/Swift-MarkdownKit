//
//  UIFont+Traits.swift
//  XHSMarkdownKit
//
//  Created by 沃顿 on 2026-02-25.
//

import UIKit

// MARK: - UIFont 特性扩展

public extension UIFont {
    
    /// 添加粗体特性
    var bold: UIFont {
        withTraits(.traitBold)
    }
    
    /// 添加斜体特性
    var italic: UIFont {
        withTraits(.traitItalic)
    }
    
    /// 添加粗斜体特性
    var boldItalic: UIFont {
        withTraits([.traitBold, .traitItalic])
    }
    
    /// 移除粗体特性
    var withoutBold: UIFont {
        withoutTraits(.traitBold)
    }
    
    /// 移除斜体特性
    var withoutItalic: UIFont {
        withoutTraits(.traitItalic)
    }
    /// 添加字体特性
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(
            fontDescriptor.symbolicTraits.union(traits)
        ) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: 0)
    }
    
    /// 设置字重
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let traits: [UIFontDescriptor.TraitKey: Any] = [
            .weight: weight
        ]
        let descriptor = fontDescriptor.addingAttributes([
            .traits: traits
        ])
        return UIFont(descriptor: descriptor, size: pointSize)
    }
    /// 移除特性
    func withoutTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        let newTraits = fontDescriptor.symbolicTraits.subtracting(traits)
        guard let descriptor = fontDescriptor.withSymbolicTraits(newTraits) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: 0)
    }
    
    /// 检查是否有特性
    func hasTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> Bool {
        fontDescriptor.symbolicTraits.contains(traits)
    }
    
    /// 是否为粗体
    var isBold: Bool {
        hasTraits(.traitBold)
    }
    
    /// 是否为斜体
    var isItalic: Bool {
        hasTraits(.traitItalic)
    }
    
    /// 是否为等宽字体
    var isMonospace: Bool {
        hasTraits(.traitMonoSpace)
    }
}

// MARK: - 便捷构造

public extension UIFont {
    
    /// 创建指定字重的系统字体
    static func system(size: CGFloat, weight: Weight = .regular) -> UIFont {
        .systemFont(ofSize: size, weight: weight)
    }
    
    /// 创建等宽数字字体
    static func monospacedDigit(size: CGFloat, weight: Weight = .regular) -> UIFont {
        .monospacedDigitSystemFont(ofSize: size, weight: weight)
    }
    
    /// 创建等宽字体
    static func monospaced(size: CGFloat, weight: Weight = .regular) -> UIFont {
        .monospacedSystemFont(ofSize: size, weight: weight)
    }
}
