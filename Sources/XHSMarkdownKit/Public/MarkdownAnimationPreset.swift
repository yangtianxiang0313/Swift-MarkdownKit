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
            animationSubmissionMode = .interruptCurrent
            typingFragmentAppearanceMode = .simultaneous

        case .typing(let cps):
            animationEffectKey = .typing
            animationSubmissionMode = .queueLatest
            typingCharactersPerSecond = max(1, cps)
            typingFragmentAppearanceMode = .sequential

        case .streamingMask(let cps):
            animationEffectKey = .streamingMask
            animationSubmissionMode = .queueLatest
            typingCharactersPerSecond = max(1, cps)
            typingFragmentAppearanceMode = .sequential
        }
    }
}
