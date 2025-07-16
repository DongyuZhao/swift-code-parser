import Foundation

extension MarkdownLanguage {
    public class BareAutoLinkBuilder: CodeElementBuilder {
        private static let regex: NSRegularExpression = {
            let pattern = #"^((https?|ftp)://[^\s<>]+|www\.[^\s<>]+|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})"#
            return try! NSRegularExpression(pattern: pattern, options: [])
        }()

        public init() {}

        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            let start = tok.range.lowerBound
            let text = String(context.input[start...])
            let range = NSRange(location: 0, length: text.utf16.count)
            if let m = Self.regex.firstMatch(in: text, range: range), m.range.location == 0 {
                return true
            }
            return false
        }

        public func build(context: inout CodeContext) {
            guard let tok = context.tokens[context.index] as? Token else { return }
            let start = tok.range.lowerBound
            let text = String(context.input[start...])
            let range = NSRange(location: 0, length: text.utf16.count)
            guard let m = Self.regex.firstMatch(in: text, range: range) else { return }
            let endPos = context.input.index(start, offsetBy: m.range.length)
            let url = String(context.input[start..<endPos])
            context.currentNode.addChild(MarkdownAutoLinkNode(url: url))
            while context.index < context.tokens.count {
                if let t = context.tokens[context.index] as? Token, t.range.upperBound <= endPos {
                    context.index += 1
                } else {
                    break
                }
            }
        }
    }

}
