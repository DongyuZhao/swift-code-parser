import Foundation
import SwiftParser

public class MarkdownURLTokenBuilder: CodeTokenBuilder {
    public typealias Token = MarkdownTokenElement

    public init() {}

    public func build(from context: inout CodeTokenContext<MarkdownTokenElement>) -> Bool {
        guard context.consuming < context.source.endIndex else { return false }
        let start = context.consuming
        let first = context.source[start]

        // Try autolink <...>
        if first == "<" {
            var index = context.source.index(after: start)
            var content = ""
            while index < context.source.endIndex {
                let char = context.source[index]
                if char == ">" {
                    let end = context.source.index(after: index)
                    let fullRange = start..<end
                    if Self.isValidAutolinkContent(content) {
                        let text = String(context.source[fullRange])
                        context.consuming = end
                        context.tokens.append(MarkdownToken.autolink(text, at: fullRange))
                        return true
                    }
                    return false
                }
                if char == " " || char == "\t" || char == "\n" || char == "\r" || char == "<" {
                    return false
                }
                content.append(char)
                index = context.source.index(after: index)
            }
            return false
        }

        let remaining = String(context.source[start...])
        if let match = remaining.firstMatch(of: Self.urlRegex) {
            let matched = String(match.1)
            let end = context.source.index(start, offsetBy: matched.count)
            context.consuming = end
            context.tokens.append(MarkdownToken.url(matched, at: start..<end))
            return true
        }

        if let match = remaining.firstMatch(of: Self.emailRegex) {
            let matched = String(match.1)
            let end = context.source.index(start, offsetBy: matched.count)
            context.consuming = end
            context.tokens.append(MarkdownToken.email(matched, at: start..<end))
            return true
        }

        return false
    }

    @preconcurrency nonisolated(unsafe) static let urlRegex = /^(https?:\/\/[^\s<>\[\]()]+)/
    @preconcurrency nonisolated(unsafe) static let emailRegex = /^([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})/

    private static func isValidAutolinkContent(_ content: String) -> Bool {
        if content.contains("@") {
            return content.firstMatch(of: emailRegex) != nil
        }
        return content.firstMatch(of: /^[a-zA-Z][a-zA-Z0-9+.-]*:[^\s]*$/) != nil
    }
}
