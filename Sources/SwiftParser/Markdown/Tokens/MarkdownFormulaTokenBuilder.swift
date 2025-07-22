import Foundation

public class MarkdownFormulaTokenBuilder: CodeTokenBuilder {
    public typealias Token = MarkdownTokenElement

    public init() {}

    public func build(from context: inout CodeTokenContext<MarkdownTokenElement>) -> Bool {
        guard context.consuming < context.source.endIndex else { return false }
        let start = context.consuming
        let char = context.source[start]

        if char == "$" {
            if let token = buildDollarFormula(from: &context, start: start) {
                context.tokens.append(token)
                return true
            }
            return false
        }

        if char == "\\" {
            if let token = buildBackslashFormula(from: &context, start: start) {
                context.tokens.append(token)
                return true
            }
            // regular backslash handled here to match old behavior
            let next = context.source.index(after: start)
            context.consuming = next
            context.tokens.append(MarkdownToken.backslash(at: start..<next))
            return true
        }

        return false
    }

    private func buildDollarFormula(from context: inout CodeTokenContext<MarkdownTokenElement>, start: String.Index) -> MarkdownToken? {
        let source = context.source
        let end = source.endIndex
        let next = source.index(after: start)
        if next < end && source[next] == "$" {
            // display math $$...$$
            var idx = source.index(after: next)
            while idx < end {
                if source[idx] == "$" {
                    let after = source.index(after: idx)
                    if after < end && source[after] == "$" {
                        let closeEnd = source.index(after: after)
                        let range = start..<closeEnd
                        context.consuming = closeEnd
                        let text = String(source[range])
                        return MarkdownToken.formulaBlock(text, at: range)
                    }
                }
                idx = source.index(after: idx)
            }
            // unclosed, take until EOF
            let range = start..<end
            context.consuming = end
            let text = String(source[range])
            return MarkdownToken.formulaBlock(text, at: range)
        } else {
            // inline math $...$
            var idx = next
            if idx < end && source[idx].isWhitespace { return nil }
            while idx < end {
                let c = source[idx]
                if c == "$" {
                    if idx > next {
                        let prev = source.index(before: idx)
                        if source[prev].isWhitespace { return nil }
                    }
                    let closeEnd = source.index(after: idx)
                    let range = start..<closeEnd
                    context.consuming = closeEnd
                    let text = String(source[range])
                    return MarkdownToken.formula(text, at: range)
                }
                if c == "\n" || c == "\r" { return nil }
                if c == "\\" {
                    let after = source.index(after: idx)
                    if after < end {
                        idx = source.index(after: after)
                    } else {
                        idx = after
                    }
                } else {
                    idx = source.index(after: idx)
                }
            }
        }
        return nil
    }

    private func buildBackslashFormula(from context: inout CodeTokenContext<MarkdownTokenElement>, start: String.Index) -> MarkdownToken? {
        let source = context.source
        let end = source.endIndex
        let next = source.index(after: start)
        guard next < end else { return nil }
        let nextChar = source[next]
        switch nextChar {
        case "[":
            var idx = source.index(after: next)
            while idx < end {
                if source[idx] == "\\" {
                    let after = source.index(after: idx)
                    if after < end && source[after] == "]" {
                        let closeEnd = source.index(after: after)
                        let range = start..<closeEnd
                        context.consuming = closeEnd
                        let text = String(source[range])
                        return MarkdownToken.formulaBlock(text, at: range)
                    }
                }
                idx = source.index(after: idx)
            }
            let range = start..<end
            context.consuming = end
            let text = String(source[range])
            return MarkdownToken.formulaBlock(text, at: range)
        case "(":
            var idx = source.index(after: next)
            while idx < end {
                let c = source[idx]
                if c == "\n" || c == "\r" {
                    let range = start..<idx
                    context.consuming = idx
                    let text = String(source[range])
                    return MarkdownToken.formula(text, at: range)
                }
                if c == "\\" {
                    let after = source.index(after: idx)
                    if after < end && source[after] == ")" {
                        let closeEnd = source.index(after: after)
                        let range = start..<closeEnd
                        context.consuming = closeEnd
                        let text = String(source[range])
                        return MarkdownToken.formula(text, at: range)
                    }
                }
                idx = source.index(after: idx)
            }
            let range = start..<end
            context.consuming = end
            let text = String(source[range])
            return MarkdownToken.formula(text, at: range)
        case "]", ")":
            let closeEnd = source.index(after: next)
            let range = start..<closeEnd
            context.consuming = closeEnd
            let text = String(source[range])
            return MarkdownToken.text(text, at: range)
        default:
            return nil
        }
    }
}


