import Foundation

/// Consumer for Markdown headings: consumes '#' tokens to start a new HeaderNode
public struct HeadingConsumer: CodeTokenConsumer {
    public typealias Node = MarkdownNodeElement
    public typealias Token = MarkdownTokenElement
    public init() {}
    public func consume(token: any CodeToken<MarkdownTokenElement>, context: inout CodeContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        guard token.element == .hash else { return false }
        // Start a new header node at level 1 (incremental hashes not handled yet)
        let header = HeaderNode(level: 1)
        context.current.append(header)
        context.current = header
        return true
    }
}

/// Consumer for newline tokens: resets context to parent node upon line break
public struct NewlineConsumer: CodeTokenConsumer {
    public typealias Node = MarkdownNodeElement
    public typealias Token = MarkdownTokenElement
    public init() {}
    public func consume(token: any CodeToken<MarkdownTokenElement>, context: inout CodeContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        guard token.element == .newline else { return false }
        // Move back up to parent context after a line break
        if let parent = context.current.parent {
            context.current = parent
        }
        return true
    }
}

/// Consumer for text tokens: appends text content to the current node
/// Consumer for text and space tokens: merges adjacent text into single TextNode
public struct TextConsumer: CodeTokenConsumer {
    public typealias Node = MarkdownNodeElement
    public typealias Token = MarkdownTokenElement
    public init() {}
    public func consume(token: any CodeToken<MarkdownTokenElement>, context: inout CodeContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        switch token.element {
        case .text:
            let content = token.text
            if let last = context.current.children.last as? TextNode {
                last.content += content
            } else {
                let textNode = TextNode(content: content)
                context.current.append(textNode)
            }
            return true
        case .space:
            // Ignore leading space in header and blockquote before text
            if (context.current is HeaderNode || context.current is BlockquoteNode) && context.current.children.isEmpty {
                return true
            }
            let content = token.text
            if let last = context.current.children.last as? TextNode {
                last.content += content
            } else {
                let textNode = TextNode(content: content)
                context.current.append(textNode)
            }
            return true
        default:
            return false
        }
    }
}

/// Consumer for EOF: ignores end-of-file token
public struct EOFConsumer: CodeTokenConsumer {
    public typealias Node = MarkdownNodeElement
    public typealias Token = MarkdownTokenElement
    public init() {}
    public func consume(token: any CodeToken<MarkdownTokenElement>, context: inout CodeContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        return token.element == .eof
    }
}
/// Consumer for inline code spans: consumes inlineCode token
public struct InlineCodeConsumer: CodeTokenConsumer {
    public typealias Node = MarkdownNodeElement
    public typealias Token = MarkdownTokenElement
    public init() {}
    public func consume(token: any CodeToken<MarkdownTokenElement>, context: inout CodeContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        guard token.element == .inlineCode, let mdToken = token as? MarkdownToken else { return false }
        // Strip surrounding backticks
        let raw = mdToken.text
        let code = raw.count >= 2 ? String(raw.dropFirst().dropLast()) : raw
        let node = InlineCodeNode(code: code)
        context.current.append(node)
        return true
    }
}
/// Consumer for block quotes: consumes '>' tokens to start a BlockquoteNode
public struct BlockquoteConsumer: CodeTokenConsumer {
    public typealias Node = MarkdownNodeElement
    public typealias Token = MarkdownTokenElement
    public init() {}
    public func consume(token: any CodeToken<MarkdownTokenElement>, context: inout CodeContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        guard token.element == .gt else { return false }
        let node = BlockquoteNode(level: 1)
        context.current.append(node)
        context.current = node
        return true
    }
}

/// Consumer for inline formulas: consumes formula token
public struct InlineFormulaConsumer: CodeTokenConsumer {
    public typealias Node = MarkdownNodeElement
    public typealias Token = MarkdownTokenElement
    public init() {}
    public func consume(token: any CodeToken<MarkdownTokenElement>, context: inout CodeContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        guard token.element == .formula, let mdToken = token as? MarkdownToken else { return false }
        // Strip surrounding dollar signs
        let raw = mdToken.text
        let expr = raw.count >= 2 ? String(raw.dropFirst().dropLast()) : raw
        let node = FormulaNode(expression: expr)
        context.current.append(node)
        return true
    }
}

/// Consumer for autolinks: consumes autolink token and creates LinkNode
public struct AutolinkConsumer: CodeTokenConsumer {
    public typealias Node = MarkdownNodeElement
    public typealias Token = MarkdownTokenElement
    public init() {}
    public func consume(token: any CodeToken<MarkdownTokenElement>, context: inout CodeContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        guard token.element == .autolink, let mdToken = token as? MarkdownToken else { return false }
        // Strip any surrounding '<' or '>'
        let raw = mdToken.text
        let url = raw.trimmingCharacters(in: CharacterSet(charactersIn: "<>") )
        let node = LinkNode(url: url, title: url)
        context.current.append(node)
        return true
    }
}

/// Consumer for bare URLs: consumes url token and creates LinkNode
public struct URLConsumer: CodeTokenConsumer {
    public typealias Node = MarkdownNodeElement
    public typealias Token = MarkdownTokenElement
    public init() {}
    public func consume(token: any CodeToken<MarkdownTokenElement>, context: inout CodeContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        guard token.element == .url else { return false }
        let url = token.text
        let node = LinkNode(url: url, title: url)
        context.current.append(node)
        return true
    }
}

/// Consumer for inline HTML: consumes htmlTag and htmlEntity tokens
public struct HTMLInlineConsumer: CodeTokenConsumer {
    public typealias Node = MarkdownNodeElement
    public typealias Token = MarkdownTokenElement
    public init() {}
    public func consume(token: any CodeToken<MarkdownTokenElement>, context: inout CodeContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        if mdToken.isHtml {
            // Inline HTML: only content matters, name is unused
            let node = HTMLNode(content: mdToken.text)
            context.current.append(node)
            return true
        }
        return false
    }
}
