import Foundation

enum MarkdownTokenBuilders {
    static func commonMarkBase() -> [any CodeTokenBuilder<MarkdownTokenElement>] {
        var builders: [any CodeTokenBuilder<MarkdownTokenElement>] = []
        // Special structures first
        builders.append(BacktickTokenBuilder())
        // Whitespace
        builders.append(WhitespaceTokenBuilder(character: " ", element: .space))
        builders.append(WhitespaceTokenBuilder(character: "\t", element: .tab))
        builders.append(WhitespaceTokenBuilder(character: "\n", element: .newline))
        builders.append(WhitespaceTokenBuilder(character: "\r", element: .carriageReturn))
        // Single character tokens
        let singles: [(Character, MarkdownTokenElement)] = [
            ("#", .hash), ("*", .asterisk), ("_", .underscore), ("-", .dash),
            ("+", .plus), ("=", .equals), ("~", .tilde), ("^", .caret),
            ("|", .pipe), (":", .colon), (";", .semicolon), ("!", .exclamation),
            ("?", .question), (".", .dot), (",", .comma), (">", .gt), ("<", .lt),
            ("&", .ampersand), ("\\", .backslash), ("/", .forwardSlash),
            ("\"", .quote), ("'", .singleQuote), ("[", .leftBracket), ("]", .rightBracket),
            ("(", .leftParen), (")", .rightParen), ("{", .leftBrace), ("}", .rightBrace)
        ]
        for (char, element) in singles {
            builders.append(SingleCharacterTokenBuilder(character: char, element: element))
        }
        // Numbers and text
        builders.append(NumberTokenBuilder())
        builders.append(TextTokenBuilder())
        return builders
    }
}
