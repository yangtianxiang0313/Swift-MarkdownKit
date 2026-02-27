//
//  FragmentIdentifiers.swift
//  XHSMarkdownKit
//

import Foundation

/// Fragment 路径前缀
public enum PathPrefix: String {
    case document = "doc"
    case blockQuote = "bq"
}

/// 节点类型名（用于 Fragment ID 生成）
public enum NodeTypeName {
    case para
    case heading(Int)
    case code
    case table
    case hr
    case img
    
    public var rawValue: String {
        switch self {
        case .para: return "para"
        case .heading(let level): return "h\(level)"
        case .code: return "code"
        case .table: return "table"
        case .hr: return "hr"
        case .img: return "img"
        }
    }
}

/// 路径组件
public enum PathComponent {
    case listItem(Int)
    case child(Int)
    
    public var rawValue: String {
        switch self {
        case .listItem(let index): return "li_\(index)"
        case .child(let index): return "c\(index)"
        }
    }
}
