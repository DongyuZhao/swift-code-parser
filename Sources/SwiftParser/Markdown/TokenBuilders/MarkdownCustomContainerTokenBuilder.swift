import Foundation

public class MarkdownCustomContainerTokenBuilder: CodeTokenBuilder {
    public typealias Token = MarkdownTokenElement

    public init() {}

    public func build(from context: inout CodeTokenContext<MarkdownTokenElement>) -> Bool {
        guard context.consuming < context.source.endIndex else { return false }
        let start = context.consuming
        let source = context.source

        guard isLineStart(source: source, index: start),
              source[start...].hasPrefix(":::") else {
            return false
        }

        var search = source.index(start, offsetBy: 3)
        var closing: String.Index? = nil
        while search < source.endIndex {
            if isLineStart(source: source, index: search) && source[search...].hasPrefix(":::") {
                closing = search
                break
            }
            search = source.index(after: search)
        }

        let end: String.Index
        if let close = closing {
            var idx = source.index(close, offsetBy: 3)
            while idx < source.endIndex && source[idx] != "\n" && source[idx] != "\r" {
                idx = source.index(after: idx)
            }
            if idx < source.endIndex {
                if source[idx] == "\r" {
                    let next = source.index(after: idx)
                    if next < source.endIndex && source[next] == "\n" {
                        idx = source.index(after: next)
                    } else {
                        idx = next
                    }
                } else {
                    idx = source.index(after: idx)
                }
            }
            end = idx
        } else {
            end = source.endIndex
        }

        context.consuming = end
        let range = start..<end
        let text = String(source[range])
        context.tokens.append(MarkdownToken.customContainer(text, at: range))
        return true
    }

    private func isLineStart(source: String, index: String.Index) -> Bool {
        if index == source.startIndex { return true }
        let prev = source[source.index(before: index)]
        return prev == "\n" || prev == "\r"
    }
}
