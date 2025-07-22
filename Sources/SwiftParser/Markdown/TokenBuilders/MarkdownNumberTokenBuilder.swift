import Foundation

public class MarkdownNumberTokenBuilder: CodeTokenBuilder {
    public typealias Token = MarkdownTokenElement

    public init() {}

    public func build(from context: inout CodeTokenContext<MarkdownTokenElement>) -> Bool {
        guard context.consuming < context.source.endIndex else { return false }
        let char = context.source[context.consuming]
        guard char.isNumber else { return false }
        let start = context.consuming
        var index = context.consuming
        while index < context.source.endIndex && context.source[index].isNumber {
            index = context.source.index(after: index)
        }
        context.consuming = index
        let text = String(context.source[start..<index])
        context.tokens.append(MarkdownToken.number(text, at: start..<index))
        return true
    }
}
