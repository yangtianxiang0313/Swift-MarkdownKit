import Foundation

public final class CompositeEffect: StepEffect {
    private let effects: [StepEffect]

    public init(effects: [StepEffect]) {
        self.effects = effects
    }

    public func apply(step: AnimationStep, host: any SceneAnimationHost) -> AnimationEffectStatus {
        for effect in effects {
            _ = effect.apply(step: step, host: host)
        }
        return .finished
    }

    public func streamDidFinish(host: any SceneAnimationHost) {
        for effect in effects {
            effect.streamDidFinish(host: host)
        }
    }
}
