//
//  LookinConfig.swift
//  ExampleApp
//
//  Lookin 调试工具配置
//  参考: https://lookin.work/faq/config-file/
//

import UIKit

extension NSObject {
    
    /// 永久折叠的 View 类列表
    /// 这些类的子视图层级在 Lookin 中会默认折叠
    @objc class func lookin_collapsedClassList() -> [String] {
        return [
            "FloatingBarContainerView",
            "_UIEditMenuListViewAnchorView"
        ]
    }
    
    /// 不捕获图像的 View
    /// 返回 NO 的 View 不会在 Lookin 中显示预览图
    @objc class func lookin_shouldCaptureImageOfView(_ view: UIView) -> Bool {
        let className = String(describing: type(of: view))
        
        // 隐藏这些系统 View 的图像
        let hiddenClasses = [
            "FloatingBarContainerView"
        ]
        
        if hiddenClasses.contains(className) {
            return false
        }
        
        return true
    }
}
