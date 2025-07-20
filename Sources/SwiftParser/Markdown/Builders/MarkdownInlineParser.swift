import Foundation

struct MarkdownInlineParser {
    static func parseInline(_ context: inout CodeContext<MarkdownNodeElement, MarkdownTokenElement>, stopAt: Set<MarkdownTokenElement> = [.newline, .eof]) -> [MarkdownNodeBase] {
        var nodes: [MarkdownNodeBase] = []
        while context.consuming < context.tokens.count {
            guard let token = context.tokens[context.consuming] as? MarkdownToken else { break }
            if stopAt.contains(token.element) { break }

            if let emphasis = parseEmphasis(&context) {
                nodes.append(emphasis)
                continue
            }
            if token.element == .inlineCode {
                nodes.append(InlineCodeNode(code: trimBackticks(token.text)))
                context.consuming += 1
                continue
            }
            if token.element == .htmlTag || token.element == .htmlBlock || token.element == .htmlUnclosedBlock || token.element == .htmlEntity {
                nodes.append(HTMLNode(content: token.text))
                context.consuming += 1
                continue
            }
            if token.element == .exclamation {
                if let image = parseImage(&context) {
                    nodes.append(image)
                    continue
                }
            }
            if token.element == .leftBracket {
                if let link = parseLinkOrFootnote(&context) {
                    nodes.append(link)
                    continue
                }
            }

            // Default text handling
            nodes.append(TextNode(content: token.text))
            context.consuming += 1
        }
        return nodes
    }

    private static func parseEmphasis(_ context: inout CodeContext<MarkdownNodeElement, MarkdownTokenElement>) -> MarkdownNodeBase? {
        guard context.consuming < context.tokens.count,
              let token = context.tokens[context.consuming] as? MarkdownToken,
              token.element == .asterisk || token.element == .underscore else { return nil }
        let delim = token.element
        var count = 1
        if context.consuming + 1 < context.tokens.count,
           let next = context.tokens[context.consuming + 1] as? MarkdownToken,
           next.element == delim {
            count = 2
        }
        let startIndex = context.consuming
        context.consuming += count
        let children = parseInline(&context, stopAt: [delim])
        var closeCount = 0
        while closeCount < count,
              context.consuming < context.tokens.count,
              let close = context.tokens[context.consuming] as? MarkdownToken,
              close.element == delim {
            closeCount += 1
            context.consuming += 1
        }
        guard closeCount == count else {
            context.consuming = startIndex
            return nil
        }
        let node: MarkdownNodeBase = (count == 2) ? StrongNode(content: "") : EmphasisNode(content: "")
        for child in children { node.append(child) }
        return node
    }

    private static func parseLinkOrFootnote(_ context: inout CodeContext<MarkdownNodeElement, MarkdownTokenElement>) -> MarkdownNodeBase? {
        let start = context.consuming
        context.consuming += 1
        // Footnote reference [^id]
        if context.consuming < context.tokens.count,
           let caret = context.tokens[context.consuming] as? MarkdownToken,
           caret.element == .caret {
            context.consuming += 1
            var ident = ""
            while context.consuming < context.tokens.count,
                  let t = context.tokens[context.consuming] as? MarkdownToken,
                  t.element != .rightBracket {
                ident += t.text
                context.consuming += 1
            }
            guard context.consuming < context.tokens.count,
                  let rb = context.tokens[context.consuming] as? MarkdownToken,
                  rb.element == .rightBracket else { context.consuming = start; return nil }
            context.consuming += 1
            return FootnoteNode(identifier: ident, content: "", referenceText: nil, range: rb.range)
        }

        let textNodes = parseInline(&context, stopAt: [.rightBracket])
        guard context.consuming < context.tokens.count,
              let rb = context.tokens[context.consuming] as? MarkdownToken,
              rb.element == .rightBracket else { context.consuming = start; return nil }
        context.consuming += 1

        // Inline link [text](url)
        if context.consuming < context.tokens.count,
           let lp = context.tokens[context.consuming] as? MarkdownToken,
           lp.element == .leftParen {
            context.consuming += 1
            var url = ""
            while context.consuming < context.tokens.count,
                  let t = context.tokens[context.consuming] as? MarkdownToken,
                  t.element != .rightParen {
                url += t.text
                context.consuming += 1
            }
            guard context.consuming < context.tokens.count,
                  let rp = context.tokens[context.consuming] as? MarkdownToken,
                  rp.element == .rightParen else { context.consuming = start; return nil }
            context.consuming += 1
            let link = LinkNode(url: url, title: "")
            for child in textNodes { link.append(child) }
            return link
        }

        // Reference link [text][id]
        if context.consuming < context.tokens.count,
           let lb = context.tokens[context.consuming] as? MarkdownToken,
           lb.element == .leftBracket {
            context.consuming += 1
            var id = ""
            while context.consuming < context.tokens.count,
                  let t = context.tokens[context.consuming] as? MarkdownToken,
                  t.element != .rightBracket {
                id += t.text
                context.consuming += 1
            }
            guard context.consuming < context.tokens.count,
                  let rb2 = context.tokens[context.consuming] as? MarkdownToken,
                  rb2.element == .rightBracket else { context.consuming = start; return nil }
            context.consuming += 1
            let ref = ReferenceNode(identifier: id, url: "", title: "")
            for child in textNodes { ref.append(child) }
            return ref
        }

        context.consuming = start
        return nil
    }

    private static func parseImage(_ context: inout CodeContext<MarkdownNodeElement, MarkdownTokenElement>) -> MarkdownNodeBase? {
        guard context.consuming + 1 < context.tokens.count,
              let lb = context.tokens[context.consuming + 1] as? MarkdownToken,
              lb.element == .leftBracket else { return nil }
        context.consuming += 2
        let altNodes = parseInline(&context, stopAt: [.rightBracket])
        guard context.consuming < context.tokens.count,
              let rb = context.tokens[context.consuming] as? MarkdownToken,
              rb.element == .rightBracket else { context.consuming -= 2; return nil }
        context.consuming += 1
        guard context.consuming < context.tokens.count,
              let lp = context.tokens[context.consuming] as? MarkdownToken,
              lp.element == .leftParen else { context.consuming -= 3; return nil }
        context.consuming += 1
        var url = ""
        while context.consuming < context.tokens.count,
              let t = context.tokens[context.consuming] as? MarkdownToken,
              t.element != .rightParen {
            url += t.text
            context.consuming += 1
        }
        guard context.consuming < context.tokens.count,
              let rp = context.tokens[context.consuming] as? MarkdownToken,
              rp.element == .rightParen else { context.consuming -= 4; return nil }
        context.consuming += 1
        let alt = altNodes.compactMap { ($0 as? TextNode)?.content }.joined()
        return ImageNode(url: url, alt: alt)
    }

    private static func trimBackticks(_ text: String) -> String {
        var t = text
        while t.hasPrefix("`") { t.removeFirst() }
        while t.hasSuffix("`") { t.removeLast() }
        return t
    }
}
