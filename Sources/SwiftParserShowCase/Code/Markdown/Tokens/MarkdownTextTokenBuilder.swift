import Foundation
import SwiftParser

public class MarkdownTextTokenBuilder: CodeTokenBuilder {
    public typealias Token = MarkdownTokenElement

    private let boundaries: Set<Character>

    public init(singleCharacterMap: [Character: MarkdownTokenElement]) {
        var set = Set(singleCharacterMap.keys)
        set.insert(" ")
        set.insert("\t")
        set.insert("\n")
        set.insert("\r")
        self.boundaries = set
    }

    public func build(from context: inout CodeTokenContext<MarkdownTokenElement>) -> Bool {
        guard context.consuming < context.source.endIndex else { return false }
        let startChar = context.source[context.consuming]

        if boundaries.contains(startChar) { return false }

        if startChar.isNumber {
            // treat as number if not surrounded by letters
            let prevIsLetter: Bool
            if context.consuming > context.source.startIndex {
                let prev = context.source[context.source.index(before: context.consuming)]
                prevIsLetter = prev.isLetter
            } else {
                prevIsLetter = false
            }

            var lookahead = context.source.index(after: context.consuming)
            var hasLetter = false
            while lookahead < context.source.endIndex {
                let c = context.source[lookahead]
                if c.isLetter { hasLetter = true; break }
                if boundaries.contains(c) { break }
                if !c.isNumber { break }
                lookahead = context.source.index(after: lookahead)
            }
            if !prevIsLetter && !hasLetter {
                return false
            }
        }

        var index = context.consuming
        while index < context.source.endIndex {
            let c = context.source[index]
            if boundaries.contains(c) { break }
            index = context.source.index(after: index)
        }
        let start = context.consuming
        context.consuming = index
        let text = String(context.source[start..<index])
        context.tokens.append(MarkdownToken.text(text, at: start..<index))
        return true
    }
}
