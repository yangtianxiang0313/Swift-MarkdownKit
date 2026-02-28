import Foundation

public struct MarkdownPreprocessor {
    private var buffer: String = ""

    public init() {}

    public mutating func append(_ chunk: String) {
        buffer += chunk
    }

    public var preclosedText: String {
        preclose(buffer)
    }

    public mutating func reset() {
        buffer = ""
    }

    public var currentText: String { buffer }

    private func preclose(_ text: String) -> String {
        var result = text
        result = precloseCodeFences(result)
        return result
    }

    private func precloseCodeFences(_ text: String) -> String {
        var openFences = 0
        let lines = text.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                openFences += 1
            }
        }
        if openFences % 2 != 0 {
            return text + "\n```"
        }
        return text
    }
}
