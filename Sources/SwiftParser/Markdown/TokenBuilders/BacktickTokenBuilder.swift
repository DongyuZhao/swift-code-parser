import Foundation

struct BacktickTokenBuilder: CodeTokenBuilder {
    typealias Element = MarkdownTokenElement

    func build(from context: CodeTokenContext<MarkdownTokenElement>) -> Bool {
        guard context.consuming < context.source.endIndex else { return false }
        guard context.source[context.consuming] == "`" else { return false }

        // Count consecutive backticks
        var idx = context.consuming
        var tickCount = 0
        while idx < context.source.endIndex && context.source[idx] == "`" {
            tickCount += 1
            idx = context.source.index(after: idx)
        }
        let start = context.consuming
        var end = idx
        var foundClosing = false

        // Search for closing sequence of same length
        while end < context.source.endIndex {
            if context.source[end] == "`" {
                var check = end
                var count = 0
                while check < context.source.endIndex && context.source[check] == "`" && count < tickCount {
                    count += 1
                    check = context.source.index(after: check)
                }
                if count == tickCount {
                    end = check
                    foundClosing = true
                    break
                }
            }
            end = context.source.index(after: end)
        }

        if !foundClosing {
            // No closing delimiter - treat first backtick as text
            return false
        }

        context.consuming = end
        let range = start..<end
        let text = String(context.source[range])
        if tickCount >= 3 {
            context.tokens.append(MarkdownToken.fencedCodeBlock(text, at: range))
        } else {
            context.tokens.append(MarkdownToken.inlineCode(text, at: range))
        }
        return true
    }
}
