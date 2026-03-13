import UIKit

public final class DisplayLinkClock: AnimationClock {
    public var onTick: ((TimeInterval) -> Void)?

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?

    public init() {}

    public func start() {
        guard displayLink == nil else { return }
        lastTimestamp = nil
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    public func stop() {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        if lastTimestamp == nil {
            lastTimestamp = link.timestamp
            return
        }

        let delta = max(0, min(link.timestamp - (lastTimestamp ?? link.timestamp), 0.2))
        lastTimestamp = link.timestamp
        onTick?(delta)
    }
}
