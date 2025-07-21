import Foundation

struct SingleCharacterTokenBuilder: CodeTokenBuilder {
    typealias Element = MarkdownTokenElement
    let character: Character
    let element: MarkdownTokenElement

    init(character: Character, element: MarkdownTokenElement) {
        self.character = character
        self.element = element
    }

    func build(from context: CodeTokenContext<MarkdownTokenElement>) -> Bool {
        guard context.consuming < context.source.endIndex else { return false }
        if context.source[context.consuming] == character {
            let start = context.consuming
            context.consuming = context.source.index(after: start)
            let token = MarkdownToken(element: element, text: String(character), range: start..<context.consuming)
            context.tokens.append(token)
            return true
        }
        return false
    }
}
