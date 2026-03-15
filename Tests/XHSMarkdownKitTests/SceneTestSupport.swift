import Foundation
@testable import XHSMarkdownKit

func mergedText(from scene: RenderScene) -> String {
    mergedText(from: scene.flattenRenderableNodes())
}

func mergedText(from nodes: [RenderScene.Node]) -> String {
    nodes.compactMap { node in
        if let text = node.component as? MergedTextSceneComponent {
            return text.attributedText.string
        }
        return nil
    }
    .joined(separator: "\n")
}
