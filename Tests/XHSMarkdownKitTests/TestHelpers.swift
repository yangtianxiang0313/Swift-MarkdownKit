import UIKit
@testable import XHSMarkdownKit

func mergedText(from fragments: [RenderFragment]) -> String {
    let merged = NSMutableAttributedString(string: "")
    for fragment in fragments {
        if let text = (fragment as? AttributedStringProviding)?.attributedString {
            merged.append(text)
            merged.append(NSAttributedString(string: "\n"))
        }
    }
    return merged.string
}
