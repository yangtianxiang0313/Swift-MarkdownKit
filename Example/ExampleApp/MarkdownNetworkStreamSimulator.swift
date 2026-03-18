import Foundation

enum MarkdownNetworkStreamSimulator {
    struct ChunkProfile: Equatable {
        let preferredCharacters: Int
        let jitterCharacters: ClosedRange<Int>
    }

    struct NetworkProfile: Equatable {
        let ttfbMs: ClosedRange<Int>
        let receiveBytes: ClosedRange<Int>
        let interPacketMs: ClosedRange<Int>
        let stallProbability: Double
        let stallMs: ClosedRange<Int>
        let burstProbability: Double
        let burstReceiveBytes: ClosedRange<Int>
        let burstInterPacketMs: ClosedRange<Int>
    }

    struct Configuration {
        let markdown: String
        let chunkProfile: ChunkProfile
        let networkProfile: NetworkProfile
    }

    enum Event {
        case started(ttfbMs: Int)
        case stalled(durationMs: Int)
        case chunk(index: Int, text: String)
        case completed(totalChunks: Int, totalBytes: Int)
    }

    static func run(
        configuration: Configuration,
        onEvent: @escaping (Event) async -> Void
    ) async {
        let chunks = makeServerChunks(
            markdown: configuration.markdown,
            profile: configuration.chunkProfile
        )
        let wirePayload = encodeFrames(chunks)
        let network = configuration.networkProfile

        let ttfb = Int.random(in: network.ttfbMs)
        await sleep(milliseconds: ttfb)
        guard !Task.isCancelled else { return }
        await onEvent(.started(ttfbMs: ttfb))

        guard !wirePayload.isEmpty else {
            await onEvent(.completed(totalChunks: 0, totalBytes: 0))
            return
        }

        var decoder = LengthPrefixedFrameDecoder()
        var offset = 0
        var deliveredChunks = 0

        while offset < wirePayload.count {
            guard !Task.isCancelled else { return }

            if Double.random(in: 0...1) < network.stallProbability {
                let stall = Int.random(in: network.stallMs)
                await onEvent(.stalled(durationMs: stall))
                await sleep(milliseconds: stall)
                guard !Task.isCancelled else { return }
            }

            let inBurst = Double.random(in: 0...1) < network.burstProbability
            let receiveRange = inBurst ? network.burstReceiveBytes : network.receiveBytes
            let receiveCount = min(
                Int.random(in: receiveRange),
                wirePayload.count - offset
            )
            let slice = wirePayload[offset..<(offset + receiveCount)]
            offset += receiveCount

            decoder.append(bytes: slice)
            let decoded = decoder.consumeAvailableFrames()
            if !decoded.isEmpty {
                for text in decoded {
                    deliveredChunks += 1
                    await onEvent(.chunk(index: deliveredChunks, text: text))
                }
            }

            if offset >= wirePayload.count { break }

            let delayRange = inBurst ? network.burstInterPacketMs : network.interPacketMs
            await sleep(milliseconds: Int.random(in: delayRange))
        }

        for text in decoder.flushRemainingFrames() {
            deliveredChunks += 1
            await onEvent(.chunk(index: deliveredChunks, text: text))
        }

        guard !Task.isCancelled else { return }
        await onEvent(
            .completed(
                totalChunks: deliveredChunks,
                totalBytes: wirePayload.count
            )
        )
    }
}

private extension MarkdownNetworkStreamSimulator {
    static func makeServerChunks(
        markdown: String,
        profile: ChunkProfile
    ) -> [String] {
        guard !markdown.isEmpty else { return [] }

        let chars = Array(markdown)
        var result: [String] = []
        result.reserveCapacity(max(1, chars.count / max(1, profile.preferredCharacters)))

        var cursor = 0
        while cursor < chars.count {
            let target = max(
                1,
                profile.preferredCharacters + Int.random(in: profile.jitterCharacters)
            )
            let end = min(chars.count, cursor + target)
            result.append(String(chars[cursor..<end]))
            cursor = end
        }
        return result
    }

    static func encodeFrames(_ chunks: [String]) -> [UInt8] {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(chunks.reduce(0) { $0 + $1.utf8.count + 4 })

        for chunk in chunks {
            let payload = Array(chunk.utf8)
            let length = UInt32(payload.count).bigEndian
            withUnsafeBytes(of: length) { pointer in
                bytes.append(contentsOf: pointer)
            }
            bytes.append(contentsOf: payload)
        }

        return bytes
    }

    static func sleep(milliseconds: Int) async {
        let clamped = max(0, milliseconds)
        try? await Task.sleep(nanoseconds: UInt64(clamped) * 1_000_000)
    }
}

private struct LengthPrefixedFrameDecoder {
    private var buffer: [UInt8] = []

    mutating func append(bytes: ArraySlice<UInt8>) {
        buffer.append(contentsOf: bytes)
    }

    mutating func consumeAvailableFrames() -> [String] {
        var frames: [String] = []
        while true {
            guard let frame = popOneFrame() else { break }
            frames.append(frame)
        }
        return frames
    }

    mutating func flushRemainingFrames() -> [String] {
        consumeAvailableFrames()
    }

    private mutating func popOneFrame() -> String? {
        guard buffer.count >= 4 else { return nil }

        let lengthPrefix = buffer[0..<4].withUnsafeBytes { pointer -> UInt32 in
            let value = pointer.load(as: UInt32.self)
            return UInt32(bigEndian: value)
        }
        let payloadLength = Int(lengthPrefix)

        guard payloadLength >= 0, buffer.count >= 4 + payloadLength else {
            return nil
        }

        let payloadRange = 4..<(4 + payloadLength)
        let payloadBytes = Array(buffer[payloadRange])
        buffer.removeFirst(4 + payloadLength)
        return String(decoding: payloadBytes, as: UTF8.self)
    }
}
