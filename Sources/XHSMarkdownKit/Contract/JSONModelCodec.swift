import Foundation

extension MarkdownContract {
    public enum JSONModelCodec {
        private static func decoder() -> JSONDecoder {
            JSONDecoder()
        }

        private static func encoder() -> JSONEncoder {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return encoder
        }

        public static func decodeCanonicalDocument(from data: Data) throws -> CanonicalDocument {
            do {
                let document = try decoder().decode(CanonicalDocument.self, from: data)
                try document.validate()
                return document
            } catch let error as MarkdownContract.ModelError {
                throw error
            } catch {
                throw MarkdownContract.ModelError.schemaInvalid(from: error)
            }
        }

        public static func encodeCanonicalDocument(_ document: CanonicalDocument) throws -> Data {
            do {
                try document.validate()
                return try encoder().encode(document)
            } catch let error as MarkdownContract.ModelError {
                throw error
            } catch {
                throw MarkdownContract.ModelError.schemaInvalid(from: error)
            }
        }

        public static func decodeRenderModel(from data: Data) throws -> RenderModel {
            do {
                let model = try decoder().decode(RenderModel.self, from: data)
                try model.validate()
                return model
            } catch let error as MarkdownContract.ModelError {
                throw error
            } catch {
                throw MarkdownContract.ModelError.schemaInvalid(from: error)
            }
        }

        public static func encodeRenderModel(_ model: RenderModel) throws -> Data {
            do {
                try model.validate()
                return try encoder().encode(model)
            } catch let error as MarkdownContract.ModelError {
                throw error
            } catch {
                throw MarkdownContract.ModelError.schemaInvalid(from: error)
            }
        }

        public static func decodeSceneSnapshot(from data: Data) throws -> SceneSnapshot {
            do {
                let snapshot = try decoder().decode(SceneSnapshot.self, from: data)
                try snapshot.validate()
                return snapshot
            } catch let error as MarkdownContract.ModelError {
                throw error
            } catch {
                throw MarkdownContract.ModelError.schemaInvalid(from: error)
            }
        }

        public static func encodeSceneSnapshot(_ snapshot: SceneSnapshot) throws -> Data {
            do {
                try snapshot.validate()
                return try encoder().encode(snapshot)
            } catch let error as MarkdownContract.ModelError {
                throw error
            } catch {
                throw MarkdownContract.ModelError.schemaInvalid(from: error)
            }
        }

        public static func decodeTimelineGraph(from data: Data) throws -> TimelineGraph {
            do {
                let graph = try decoder().decode(TimelineGraph.self, from: data)
                try graph.validate()
                return graph
            } catch let error as MarkdownContract.ModelError {
                throw error
            } catch {
                throw MarkdownContract.ModelError.schemaInvalid(from: error)
            }
        }

        public static func encodeTimelineGraph(_ graph: TimelineGraph) throws -> Data {
            do {
                try graph.validate()
                return try encoder().encode(graph)
            } catch let error as MarkdownContract.ModelError {
                throw error
            } catch {
                throw MarkdownContract.ModelError.schemaInvalid(from: error)
            }
        }
    }
}
