//
//  RendererCategory.swift
//  XHSMarkdownKit
//

import Foundation

/// 渲染器通配类别（用于 RendererRegistry 的通配匹配）
public enum RendererCategory: String {
    case heading = "heading"
    case list = "list"
    case taskListItem = "taskListItem"
}
