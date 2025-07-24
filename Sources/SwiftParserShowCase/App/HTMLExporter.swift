import SwiftParser

struct HTMLExporter {
    static func export(node: CodeNode<MarkdownNodeElement>) -> String {
        guard let markdownNode = node as? MarkdownNodeBase else {
            return node.children.map { export(node: $0) }.joined()
        }
        return render(markdownNode)
    }

    private static func render(_ node: MarkdownNodeBase) -> String {
        switch node {
        case let document as DocumentNode:
            return document.children().map { render($0) }.joined(separator: "\n")
        case let header as HeaderNode:
            let body = header.children().map { render($0) }.joined()
            return "<h\(header.level)>\(body)</h\(header.level)>"
        case is ParagraphNode:
            let body = node.children().map { render($0) }.joined()
            return "<p>\(body)</p>"
        case is EmphasisNode:
            let body = node.children().map { render($0) }.joined()
            return "<em>\(body)</em>"
        case is StrongNode:
            let body = node.children().map { render($0) }.joined()
            return "<strong>\(body)</strong>"
        case is StrikeNode:
            let body = node.children().map { render($0) }.joined()
            return "<del>\(body)</del>"
        case let text as TextNode:
            return escape(text.content)
        case let code as InlineCodeNode:
            return "<code>\(escape(code.code))</code>"
        case let block as CodeBlockNode:
            let lang = block.language.map { " class=\"language-\($0)\"" } ?? ""
            return "<pre><code\(lang)>\(escape(block.source))</code></pre>"
        case is BlockquoteNode:
            let body = node.children().map { render($0) }.joined()
            return "<blockquote>\(body)</blockquote>"
        case let list as OrderedListNode:
            let body = list.children().map { render($0) }.joined()
            return "<ol start=\(list.start)>\(body)</ol>"
        case is UnorderedListNode:
            let body = node.children().map { render($0) }.joined()
            return "<ul>\(body)</ul>"
        case is ListItemNode:
            let body = node.children().map { render($0) }.joined()
            return "<li>\(body)</li>"
        case is ThematicBreakNode:
            return "<hr/>"
        case let link as LinkNode:
            let body = link.children().map { render($0) }.joined()
            return "<a href=\"\(escape(link.url))\">\(body)</a>"
        case let image as ImageNode:
            return "<img src=\"\(escape(image.url))\" alt=\"\(escape(image.alt))\"/>"
        case let html as HTMLNode:
            return html.content
        case let htmlBlock as HTMLBlockNode:
            return "<\(htmlBlock.name)>\(htmlBlock.content)</\(htmlBlock.name)>"
        case is LineBreakNode:
            return "<br/>"
        default:
            return node.children().map { render($0) }.joined()
        }
    }

    private static func escape(_ text: String) -> String {
        var escaped = text
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        escaped = escaped.replacingOccurrences(of: "'", with: "&#39;")
        return escaped
    }
}
