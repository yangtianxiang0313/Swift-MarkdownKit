import Foundation

public struct AnimationEffectKey: Hashable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public enum ContentEntityAppearanceMode {
    case sequential
    case simultaneous
}

public extension AnimationEffectKey {
    static let instant = AnimationEffectKey(rawValue: "instant")
    static let typing = AnimationEffectKey(rawValue: "typing")
    static let segmentFade = AnimationEffectKey(rawValue: "segmentFade")
    static let maskReveal = AnimationEffectKey(rawValue: "maskReveal")
    static let streamingMask = AnimationEffectKey(rawValue: "streamingMask")
}
