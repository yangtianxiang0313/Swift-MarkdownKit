import Foundation

public enum MarkdownAnimationPreset {
    case instant
    case typing(charactersPerSecond: Int)
    case streamingMask(charactersPerSecond: Int)
}

public extension MarkdownContainerView {
    func setAnimationPreset(_ preset: MarkdownAnimationPreset) {
        switch preset {
        case .instant:
            animationEffectKey = .instant
            animationConcurrencyPolicy = .fullyOrdered
            animationMode = .instant
            contentEntityAppearanceMode = .simultaneous

        case .typing(let cps):
            animationEffectKey = .typing
            animationConcurrencyPolicy = .fullyOrdered
            animationMode = .dualPhase
            typingCharactersPerSecond = max(1, cps)
            contentEntityAppearanceMode = .sequential

        case .streamingMask(let cps):
            animationEffectKey = .streamingMask
            animationConcurrencyPolicy = .fullyOrdered
            animationMode = .dualPhase
            typingCharactersPerSecond = max(1, cps)
            contentEntityAppearanceMode = .sequential
        }
    }
}
