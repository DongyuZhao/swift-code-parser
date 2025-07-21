import Foundation

struct NumberTokenBuilder: CodeTokenBuilder {
    typealias Element = MarkdownTokenElement
    func build(from context: CodeTokenContext<MarkdownTokenElement>) -> Bool {
        guard context.consuming < context.source.endIndex else { return false }
        var idx = context.consuming
        var hasDigit = false
        while idx < context.source.endIndex && context.source[idx].isNumber {
            idx = context.source.index(after: idx)
            hasDigit = true
        }
        guard hasDigit else { return false }
        let range = context.consuming..<idx
        let text = String(context.source[range])
        context.consuming = idx
        context.tokens.append(MarkdownToken.number(text, at: range))
        return true
    }
}
