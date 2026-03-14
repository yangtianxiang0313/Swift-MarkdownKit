import Foundation
@testable import XHSMarkdownKit

func mergedText(from scene: RenderScene) -> String {
    mergedText(from: scene.flattenRenderableNodes())
}

func mergedText(from nodes: [RenderScene.Node]) -> String {
    nodes.compactMap { node in
        guard let text = node.component as? TextSceneComponent else { return nil }
        return text.attributedText.string
    }
    .joined(separator: "\n")
}
