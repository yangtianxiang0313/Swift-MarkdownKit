import Foundation

public final class StreamingTextBuffer {
    private var chunks: [String] = []

    public init() {}

    public func append(_ chunk: String) {
        chunks.append(chunk)
    }

    public var fullText: String {
        chunks.joined()
    }

    public func clear() {
        chunks.removeAll()
    }
}
