import Foundation
#if canImport(XHSMarkdownCore)
import XHSMarkdownCore
#endif

struct SceneInteractionPayload: Equatable {
    var action: String
    var payload: [String: MarkdownContract.Value]

    init(action: String, payload: [String: MarkdownContract.Value] = [:]) {
        self.action = action
        self.payload = payload
    }
}

protocol SceneInteractionEmitting: AnyObject {
    var sceneInteractionHandler: ((SceneInteractionPayload) -> Bool)? { get set }
}
