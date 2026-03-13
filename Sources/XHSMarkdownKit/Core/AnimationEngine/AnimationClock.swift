import Foundation

public protocol AnimationClock: AnyObject {
    var onTick: ((TimeInterval) -> Void)? { get set }
    func start()
    func stop()
}
