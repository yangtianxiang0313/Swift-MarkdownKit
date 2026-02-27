import Foundation
import UIKit

// MARK: - EnterAnimationExecutor Protocol

/// 进入动画执行器协议
/// 定义 View 的进入动画如何执行
public protocol EnterAnimationExecutor {
    
    /// 执行进入动画
    /// - Parameters:
    ///   - view: 要动画的 View
    ///   - config: 动画配置
    ///   - theme: 主题配置（包含动画参数）
    ///   - completion: 完成回调
    func execute(
        _ view: UIView,
        config: EnterAnimationConfig,
        theme: MarkdownTheme,
        completion: @escaping () -> Void
    )
}

// MARK: - DefaultEnterAnimationExecutor

/// 默认进入动画执行器
public final class DefaultEnterAnimationExecutor: EnterAnimationExecutor {
    
    public init() {}
    
    public func execute(
        _ view: UIView,
        config: EnterAnimationConfig,
        theme: MarkdownTheme,
        completion: @escaping () -> Void
    ) {
        let enterStyle = theme.animation.enter
        
        switch config.type {
        case .fadeIn:
            executeFadeIn(view, duration: config.duration, completion: completion)
            
        case .slideUp:
            executeSlideUp(view, duration: config.duration, offset: enterStyle.slideUpOffset, completion: completion)
            
        case .expand:
            executeExpand(view, duration: config.duration, completion: completion)
            
        case .none:
            completion()
            
        case .custom(let animator):
            animator(view, completion)
        }
    }
    
    // MARK: - Private Animations
    
    private func executeFadeIn(_ view: UIView, duration: TimeInterval, completion: @escaping () -> Void) {
        view.alpha = 0
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: .curveEaseOut,
            animations: { view.alpha = 1 },
            completion: { _ in completion() }
        )
    }
    
    private func executeSlideUp(_ view: UIView, duration: TimeInterval, offset: CGFloat, completion: @escaping () -> Void) {
        view.transform = CGAffineTransform(translationX: 0, y: offset)
        view.alpha = 0
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: .curveEaseOut,
            animations: {
                view.transform = .identity
                view.alpha = 1
            },
            completion: { _ in completion() }
        )
    }
    
    private func executeExpand(_ view: UIView, duration: TimeInterval, completion: @escaping () -> Void) {
        view.clipsToBounds = true
        let targetHeight = view.frame.height
        view.frame.size.height = 0
        view.alpha = 0
        
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: .curveEaseOut,
            animations: {
                view.frame.size.height = targetHeight
                view.alpha = 1
            },
            completion: { _ in completion() }
        )
    }
}

// MARK: - SpringEnterAnimationExecutor

/// 弹性进入动画执行器
public final class SpringEnterAnimationExecutor: EnterAnimationExecutor {
    
    public init() {}
    
    public func execute(
        _ view: UIView,
        config: EnterAnimationConfig,
        theme: MarkdownTheme,
        completion: @escaping () -> Void
    ) {
        let enterStyle = theme.animation.enter
        
        switch config.type {
        case .fadeIn, .slideUp:
            executeSpringSlide(
                view,
                duration: config.duration,
                damping: enterStyle.springDamping,
                velocity: enterStyle.springVelocity,
                scaleRatio: enterStyle.scaleRatio,
                slideOffset: enterStyle.slideUpOffset * enterStyle.springSlideOffsetRatio,
                completion: completion
            )
            
        case .expand:
            executeSpringExpand(
                view,
                duration: config.duration,
                damping: enterStyle.springDamping,
                velocity: enterStyle.springVelocity,
                expandInitialScale: enterStyle.expandInitialScale,
                completion: completion
            )
            
        case .none:
            completion()
            
        case .custom(let animator):
            animator(view, completion)
        }
    }
    
    private func executeSpringSlide(
        _ view: UIView,
        duration: TimeInterval,
        damping: CGFloat,
        velocity: CGFloat,
        scaleRatio: CGFloat,
        slideOffset: CGFloat,
        completion: @escaping () -> Void
    ) {
        view.transform = CGAffineTransform(scaleX: scaleRatio, y: scaleRatio).translatedBy(x: 0, y: slideOffset)
        view.alpha = 0
        
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: damping,
            initialSpringVelocity: velocity,
            options: [],
            animations: {
                view.transform = .identity
                view.alpha = 1
            },
            completion: { _ in completion() }
        )
    }
    
    private func executeSpringExpand(
        _ view: UIView,
        duration: TimeInterval,
        damping: CGFloat,
        velocity: CGFloat,
        expandInitialScale: CGFloat,
        completion: @escaping () -> Void
    ) {
        view.transform = CGAffineTransform(scaleX: expandInitialScale, y: 0)
        view.alpha = 0
        
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: damping,
            initialSpringVelocity: velocity,
            options: [],
            animations: {
                view.transform = .identity
                view.alpha = 1
            },
            completion: { _ in completion() }
        )
    }
}
