import Foundation

public class MarkdownCodeTokenBuilder: CodeTokenBuilder {
    public typealias Token = MarkdownTokenElement

    public init() {}

    public func build(from context: inout CodeTokenContext<MarkdownTokenElement>) -> Bool {
        guard context.consuming < context.source.endIndex else { return false }
        let start = context.consuming
        let char = context.source[start]

        if char == "`" {
            if let token = buildFencedCode(from: &context, start: start) {
                context.tokens.append(token)
                return true
            }
            if let token = buildInlineCode(from: &context, start: start) {
                context.tokens.append(token)
                return true
            }
            let next = context.source.index(after: start)
            context.consuming = next
            context.tokens.append(MarkdownToken.text("`", at: start..<next))
            return true
        }

        if (char == " " || char == "\t") && isLineStart(source: context.source, index: start) {
            if let token = buildIndentedCode(from: &context, start: start) {
                context.tokens.append(token)
                return true
            }
        }

        return false
    }

    private func isLineStart(source: String, index: String.Index) -> Bool {
        if index == source.startIndex { return true }
        let prev = source.index(before: index)
        let c = source[prev]
        return c == "\n" || c == "\r"
    }

    private func buildFencedCode(from context: inout CodeTokenContext<MarkdownTokenElement>, start: String.Index) -> MarkdownToken? {
        var tickCount = 0
        var idx = start
        while idx < context.source.endIndex && context.source[idx] == "`" {
            tickCount += 1
            idx = context.source.index(after: idx)
        }
        if tickCount < 3 { return nil }

        // skip language specifier until newline
        while idx < context.source.endIndex && context.source[idx] != "\n" && context.source[idx] != "\r" {
            idx = context.source.index(after: idx)
        }

        // skip newline
        if idx < context.source.endIndex {
            if context.source[idx] == "\r" {
                let next = context.source.index(after: idx)
                if next < context.source.endIndex && context.source[next] == "\n" {
                    idx = context.source.index(after: next)
                } else {
                    idx = next
                }
            } else if context.source[idx] == "\n" {
                idx = context.source.index(after: idx)
            }
        }

        var search = idx
        var closingStart: String.Index? = nil
        while search < context.source.endIndex {
            if context.source[search] == "`" {
                let fenceStart = search
                var count = 0
                while search < context.source.endIndex && context.source[search] == "`" {
                    count += 1
                    search = context.source.index(after: search)
                }
                if count >= tickCount {
                    closingStart = fenceStart
                    break
                }
            } else {
                search = context.source.index(after: search)
            }
        }

        let end: String.Index
        if let closing = closingStart {
            end = search
            context.consuming = search
        } else {
            end = context.source.endIndex
            context.consuming = context.source.endIndex
        }

        let range = start..<end
        let text = String(context.source[range])
        return MarkdownToken.fencedCodeBlock(text, at: range)
    }

    private func buildInlineCode(from context: inout CodeTokenContext<MarkdownTokenElement>, start: String.Index) -> MarkdownToken? {
        var idx = context.source.index(after: start)
        while idx < context.source.endIndex {
            if context.source[idx] == "`" {
                let end = context.source.index(after: idx)
                let range = start..<end
                context.consuming = end
                let text = String(context.source[range])
                return MarkdownToken.inlineCode(text, at: range)
            }
            if context.source[idx] == "\\" {
                let next = context.source.index(after: idx)
                if next < context.source.endIndex {
                    idx = context.source.index(after: next)
                } else {
                    idx = next
                }
            } else {
                idx = context.source.index(after: idx)
            }
        }
        return nil
    }

    private func buildIndentedCode(from context: inout CodeTokenContext<MarkdownTokenElement>, start: String.Index) -> MarkdownToken? {
        var idx = start
        var spaceCount = 0
        while idx < context.source.endIndex {
            if context.source[idx] == " " {
                spaceCount += 1
                if spaceCount >= 4 {
                    idx = context.source.index(after: idx)
                    break
                }
            } else if context.source[idx] == "\t" {
                spaceCount = 4
                idx = context.source.index(after: idx)
                break
            } else {
                break
            }
            idx = context.source.index(after: idx)
        }
        if spaceCount < 4 { return nil }

        var hasContent = false
        var check = idx
        while check < context.source.endIndex && context.source[check] != "\n" && context.source[check] != "\r" {
            if context.source[check] != " " && context.source[check] != "\t" {
                hasContent = true
                break
            }
            check = context.source.index(after: check)
        }
        if !hasContent { return nil }

        let blockStart = start
        var blockEnd = start
        var scan = idx
        while scan < context.source.endIndex {
            while scan < context.source.endIndex && context.source[scan] != "\n" && context.source[scan] != "\r" {
                scan = context.source.index(after: scan)
            }
            blockEnd = scan
            if scan < context.source.endIndex {
                if context.source[scan] == "\r" {
                    scan = context.source.index(after: scan)
                    if scan < context.source.endIndex && context.source[scan] == "\n" {
                        scan = context.source.index(after: scan)
                    }
                } else if context.source[scan] == "\n" {
                    scan = context.source.index(after: scan)
                }
            }
            let lineStart = scan
            var indent = 0
            var blank = true
            while scan < context.source.endIndex && context.source[scan] != "\n" && context.source[scan] != "\r" {
                if context.source[scan] == " " {
                    indent += 1
                } else if context.source[scan] == "\t" {
                    indent = 4
                    blank = false
                    break
                } else {
                    blank = false
                    break
                }
                scan = context.source.index(after: scan)
            }
            if blank { continue }
            if indent < 4 { break }
            scan = lineStart
        }

        let range = blockStart..<blockEnd
        let text = String(context.source[range])
        context.consuming = blockEnd
        return MarkdownToken.indentedCodeBlock(text, at: range)
    }
}
