import Foundation
import SwiftParser

public class MarkdownNumberTokenBuilder: CodeTokenBuilder {
    public typealias Token = MarkdownTokenElement

    public init() {}

    public func build(from context: inout CodeTokenContext<MarkdownTokenElement>) -> Bool {
        guard context.consuming < context.source.endIndex else { return false }
        let char = context.source[context.consuming]
        guard char.isNumber else { return false }

        // If the number is part of an alphanumeric sequence, treat it as text
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
            if !c.isNumber { break }
            lookahead = context.source.index(after: lookahead)
        }
        if prevIsLetter || hasLetter {
            return false
        }

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
