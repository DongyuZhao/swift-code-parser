import Foundation

struct WhitespaceTokenBuilder: CodeTokenBuilder {
    typealias Element = MarkdownTokenElement
    private let character: Character
    private let element: MarkdownTokenElement

    init(character: Character, element: MarkdownTokenElement) {
        self.character = character
        self.element = element
    }

    func build(from context: CodeTokenContext<MarkdownTokenElement>) -> Bool {
        guard context.consuming < context.source.endIndex else { return false }
        if element == .newline || element == .carriageReturn {
            return buildNewline(from: context)
        }
        if context.source[context.consuming] == character {
            let start = context.consuming
            context.consuming = context.source.index(after: start)
            let token = MarkdownToken(element: element, text: String(character), range: start..<context.consuming)
            context.tokens.append(token)
            return true
        }
        return false
    }

    private func buildNewline(from context: CodeTokenContext<MarkdownTokenElement>) -> Bool {
        let index = context.consuming
        let char = context.source[index]
        if char == "\n" {
            context.consuming = context.source.index(after: index)
            let token = MarkdownToken.newline(at: index..<context.consuming)
            context.tokens.append(token)
            return true
        } else if char == "\r" {
            let next = context.source.index(after: index)
            if next < context.source.endIndex && context.source[next] == "\n" {
                context.consuming = context.source.index(after: next)
                let token = MarkdownToken.newline(at: index..<context.consuming)
                context.tokens.append(token)
            } else {
                context.consuming = next
                let token = MarkdownToken(element: .carriageReturn, text: "\r", range: index..<context.consuming)
                context.tokens.append(token)
            }
            return true
        }
        return false
    }
}
