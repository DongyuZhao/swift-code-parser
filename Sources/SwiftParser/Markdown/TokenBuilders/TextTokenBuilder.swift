import Foundation

struct TextTokenBuilder: CodeTokenBuilder {
    typealias Element = MarkdownTokenElement

    func build(from context: CodeTokenContext<MarkdownTokenElement>) -> Bool {
        guard context.consuming < context.source.endIndex else { return false }
        var idx = context.consuming
        while idx < context.source.endIndex {
            let c = context.source[idx]
            if isSpecial(c) { break }
            idx = context.source.index(after: idx)
        }
        guard idx > context.consuming else { return false }
        let range = context.consuming..<idx
        let text = String(context.source[range])
        context.consuming = idx
        context.tokens.append(MarkdownToken.text(text, at: range))
        return true
    }

    private func isSpecial(_ char: Character) -> Bool {
        switch char {
        case "#", "*", "_", "`", "-", "+", "=", "~", "^", "|", ":", ";", "!", "?", ".", ",", ">", "<", "&", "\\", "/", "\"", "'", "[", "]", "(", ")", "{", "}", "$":
            return true
        case " ", "\t", "\n", "\r":
            return true
        default:
            return false
        }
    }
}
