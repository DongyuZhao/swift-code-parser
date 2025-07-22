import Foundation

public class MarkdownWhitespaceTokenBuilder: CodeTokenBuilder {
    public typealias Token = MarkdownTokenElement

    public init() {}

    public func build(from context: inout CodeTokenContext<MarkdownTokenElement>) -> Bool {
        guard context.consuming < context.source.endIndex else { return false }
        let char = context.source[context.consuming]

        switch char {
        case " ":
            let start = context.consuming
            context.consuming = context.source.index(after: context.consuming)
            context.tokens.append(MarkdownToken.space(at: start..<context.consuming))
            return true
        case "\t":
            let start = context.consuming
            context.consuming = context.source.index(after: context.consuming)
            context.tokens.append(MarkdownToken.tab(at: start..<context.consuming))
            return true
        case "\n":
            let start = context.consuming
            context.consuming = context.source.index(after: context.consuming)
            context.tokens.append(MarkdownToken.newline(at: start..<context.consuming))
            return true
        case "\r":
            let start = context.consuming
            let next = context.source.index(after: context.consuming)
            if next < context.source.endIndex && context.source[next] == "\n" {
                let end = context.source.index(after: next)
                context.consuming = end
                let range = start..<end
                context.tokens.append(MarkdownToken(element: .newline, text: "\r\n", range: range))
            } else {
                context.consuming = next
                let range = start..<context.consuming
                context.tokens.append(MarkdownToken(element: .carriageReturn, text: "\r", range: range))
            }
            return true
        default:
            return false
        }
    }
}
