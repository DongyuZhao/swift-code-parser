import Foundation

public struct MarkdownLanguage: CodeLanguage {



    // Helper to parse inline content supporting nested emphasis/strong
    static func parseInline(context: inout CodeContext, closing: Token, count: Int) -> ([CodeNode], Bool) {
        var nodes: [CodeNode] = []
        var text = ""
        var closed = false
        func flush() {
            if !text.isEmpty {
                nodes.append(MarkdownTextNode(value: text))
                text = ""
            }
        }
        while context.index < context.tokens.count {
            guard let tok = context.tokens[context.index] as? Token else { context.index += 1; continue }
            // Check for closing delimiter first
            if tok.kindDescription == closing.kindDescription {
                var idx = context.index
                var cnt = 0
                while idx < context.tokens.count, let t = context.tokens[idx] as? Token,
                      t.kindDescription == closing.kindDescription {
                    cnt += 1; idx += 1
                }
                if cnt == count {
                    context.index = idx
                    flush()
                    closed = true
                    break
                }
            }

            // Strong delimiter
            if (tok.kindDescription == "*" || tok.kindDescription == "_") &&
               context.index + 1 < context.tokens.count,
               let next = context.tokens[context.index + 1] as? Token,
               next.kindDescription == tok.kindDescription {
                flush()
                context.index += 2
                let (inner, ok) = parseInline(context: &context, closing: tok, count: 2)
                if ok {
                    let node = MarkdownStrongNode(value: "")
                    inner.forEach { node.addChild($0) }
                    nodes.append(node)
                    continue
                } else {
                    text += tok.text + next.text
                    continue
                }
            }

            // Emphasis delimiter
            if tok.kindDescription == "*" || tok.kindDescription == "_" {
                flush()
                context.index += 1
                let (inner, ok) = parseInline(context: &context, closing: tok, count: 1)
                if ok {
                    let node = MarkdownEmphasisNode(value: "")
                    inner.forEach { node.addChild($0) }
                    nodes.append(node)
                    continue
                } else {
                    text += tok.text
                    continue
                }
            }

            // Inline code
            if tok.kindDescription == "`" {
                flush()
                context.index += 1
                var codeText = ""
                while context.index < context.tokens.count {
                    if let t = context.tokens[context.index] as? Token {
                        if t.kindDescription == "`" {
                            context.index += 1
                            let node = MarkdownInlineCodeNode(value: codeText)
                            nodes.append(node)
                            break
                        } else {
                            codeText += t.text
                            context.index += 1
                        }
                    } else { context.index += 1 }
                }
                continue
            }

            text += tok.text
            context.index += 1
        }
        flush()
        return (nodes, closed)
    }

    /// Parse a sequence of tokens as inline content and return the resulting nodes.
    /// This is a convenience wrapper around `parseInline` that treats the entire
    /// token list as a single inline segment.
    static func parseInlineTokens(_ tokens: [Token], input: String) -> [CodeNode] {
        let eofRange = tokens.last?.range ?? input.startIndex..<input.startIndex
        var ctx = CodeContext(tokens: tokens + [.eof(eofRange)],
                              index: 0,
                              currentNode: CodeNode(type: Element.root, value: ""),
                              errors: [],
                              input: input)
        let closing = Token.eof(eofRange)
        let (nodes, _) = parseInline(context: &ctx, closing: closing, count: 1)
        return nodes
    }

    static func isHTMLClosed(_ text: String) -> Bool {
        let voidTags: Set<String> = ["area","base","br","col","embed","hr","img","input","link","meta","param","source","track","wbr"]
        let pattern = #"<(/?)([A-Za-z][A-Za-z0-9]*)[^>]*?(\/?)>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return false }
        var stack: [String] = []
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        regex.enumerateMatches(in: text, options: [], range: nsRange) { m, _, _ in
            guard let m = m else { return }
            let closingRange = m.range(at: 1)
            let tagRange = m.range(at: 2)
            let selfClosingRange = m.range(at: 3)
            guard let tagNameRange = Range(tagRange, in: text) else { return }
            let name = text[tagNameRange].lowercased()
            let isClosing = closingRange.location != NSNotFound && Range(closingRange, in: text).map { text[$0] } == "/"
            let isSelfClosing = selfClosingRange.location != NSNotFound && Range(selfClosingRange, in: text).map { text[$0] } == "/" || voidTags.contains(name)
            if isClosing {
                if let last = stack.last, last == name { stack.removeLast() }
            } else if !isSelfClosing {
                stack.append(name)
            }
        }
        return stack.isEmpty
    }


    public var tokenizer: CodeTokenizer { Tokenizer() }
    public var builders: [CodeElementBuilder] {
        [HeadingBuilder(), SetextHeadingBuilder(), CodeBlockBuilder(), IndentedCodeBlockBuilder(), BlockQuoteBuilder(), ThematicBreakBuilder(), OrderedListBuilder(), UnorderedListBuilder(), ImageBuilder(), HTMLBlockBuilder(), HTMLBuilder(), EntityBuilder(), StrikethroughBuilder(), AutoLinkBuilder(), BareAutoLinkBuilder(), TableBuilder(), FootnoteBuilder(), LinkReferenceDefinitionBuilder(), LinkBuilder(), ParagraphBuilder()]
    }
    public var expressionBuilders: [CodeExpressionBuilder] { [] }
    public var rootElement: any CodeElement { Element.root }
    public init() {}
}
