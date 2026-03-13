import Foundation

extension MarkdownContract {
    public struct StreamingRenderUpdate: Sendable, Equatable, Codable {
        public var schemaVersion: Int
        public var sequence: Int
        public var isFinal: Bool
        public var currentText: String
        public var document: CanonicalDocument
        public var model: RenderModel
        public var diff: RenderModelDiff
        public var animationPlan: CompiledAnimationPlan

        public init(
            schemaVersion: Int = MarkdownContract.schemaVersion,
            sequence: Int,
            isFinal: Bool,
            currentText: String,
            document: CanonicalDocument,
            model: RenderModel,
            diff: RenderModelDiff,
            animationPlan: CompiledAnimationPlan
        ) {
            self.schemaVersion = schemaVersion
            self.sequence = sequence
            self.isFinal = isFinal
            self.currentText = currentText
            self.document = document
            self.model = model
            self.diff = diff
            self.animationPlan = animationPlan
        }
    }

    public final class StreamingMarkdownSession {
        private let engine: MarkdownContractEngine
        private let differ: any RenderModelDiffer
        private let animationCompiler: any RenderModelAnimationCompiler
        private let parseOptions: MarkdownContractParserOptions
        private let renderOptions: CanonicalRenderOptions

        private var buffer: String = ""
        private var sequence: Int = 0
        private var lastModel: RenderModel?

        public init(
            engine: MarkdownContractEngine = MarkdownContractEngine(),
            differ: any RenderModelDiffer = DefaultRenderModelDiffer(),
            animationCompiler: any RenderModelAnimationCompiler = DefaultRenderModelAnimationCompiler(),
            parseOptions: MarkdownContractParserOptions = MarkdownContractParserOptions(),
            renderOptions: CanonicalRenderOptions = CanonicalRenderOptions()
        ) {
            self.engine = engine
            self.differ = differ
            self.animationCompiler = animationCompiler
            self.parseOptions = parseOptions
            self.renderOptions = renderOptions
        }

        public var currentText: String {
            buffer
        }

        public func appendChunk(_ chunk: String) throws -> StreamingRenderUpdate {
            buffer.append(chunk)
            return try renderCurrent(isFinal: false)
        }

        public func finish() throws -> StreamingRenderUpdate {
            try renderCurrent(isFinal: true)
        }

        public func reset() {
            buffer = ""
            sequence = 0
            lastModel = nil
        }

        private func renderCurrent(isFinal: Bool) throws -> StreamingRenderUpdate {
            let document = engine.parse(buffer, options: parseOptions)
            let rewritten = try engine.transform(document)
            let model = try engine.renderer.render(document: rewritten, options: renderOptions)

            let oldModel = lastModel ?? RenderModel(
                documentId: model.documentId,
                blocks: [],
                assets: [],
                metadata: [:]
            )

            let diff = differ.diff(old: oldModel, new: model)
            let animationPlan = animationCompiler.compile(old: oldModel, new: model, diff: diff)

            sequence += 1
            lastModel = model

            return StreamingRenderUpdate(
                sequence: sequence,
                isFinal: isFinal,
                currentText: buffer,
                document: rewritten,
                model: model,
                diff: diff,
                animationPlan: animationPlan
            )
        }
    }
}
