import Foundation
import SwiftParser

public final class MarkdownExporter {
    public init() {}

    public func export(_ root: CodeNode<MarkdownNodeElement>) -> String {
        guard let node = root as? MarkdownNodeBase else { return "" }
        return render(node)
    }

    private func render(_ node: MarkdownNodeBase) -> String {
        switch node {
        case let document as DocumentNode:
            return document.children().map { render($0) }.joined(separator: "\n")
        case let header as HeaderNode:
            return "<h\(header.level)>" + renderChildren(header) + "</h\(header.level)>"
        case is ParagraphNode:
            return "<p>" + renderChildren(node) + "</p>"
        case is BlockquoteNode:
            return "<blockquote>" + renderChildren(node) + "</blockquote>"
        case let list as OrderedListNode:
            return "<ol start=\"\(list.start)\">" + renderChildren(list) + "</ol>"
        case is UnorderedListNode:
            return "<ul>" + renderChildren(node) + "</ul>"
        case is ListItemNode:
            return "<li>" + renderChildren(node) + "</li>"
        case let code as CodeBlockNode:
            return "<pre><code>" + escape(code.source) + "</code></pre>"
        case let html as HTMLBlockNode:
            return html.content
        case let formulaBlock as FormulaBlockNode:
            return formulaBlock.expression
        case let text as TextNode:
            return escape(text.content)
        case is EmphasisNode:
            return "<em>" + renderChildren(node) + "</em>"
        case is StrongNode:
            return "<strong>" + renderChildren(node) + "</strong>"
        case is StrikeNode:
            return "<del>" + renderChildren(node) + "</del>"
        case let code as InlineCodeNode:
            return "<code>" + escape(code.code) + "</code>"
        case let link as LinkNode:
            return "<a href=\"" + escapeAttribute(link.url) + "\">" + (link.title.isEmpty ? renderChildren(link) : escape(link.title)) + "</a>"
        case let image as ImageNode:
            return "<img src=\"" + escapeAttribute(image.url) + "\" alt=\"" + escapeAttribute(image.alt) + "\"/>"
        case let html as HTMLNode:
            return html.content
        case is LineBreakNode:
            return "<br/>"
        case let comment as CommentNode:
            return "<!-- " + comment.content + " -->"
        case is TableNode:
            return "<table>" + renderChildren(node) + "</table>"
        case is TableHeaderNode:
            return "<thead>" + renderChildren(node) + "</thead>"
        case is TableRowNode:
            return "<tr>" + renderChildren(node) + "</tr>"
        case is TableCellNode:
            return "<td>" + renderChildren(node) + "</td>"
        case is TaskListNode:
            return "<ul>" + renderChildren(node) + "</ul>"
        case let task as TaskListItemNode:
            let checked = task.checked ? " checked" : ""
            return "<li><input type=\"checkbox\"" + checked + "/> " + renderChildren(task) + "</li>"
        case let reference as ReferenceNode:
            return "[\(reference.identifier)]: \(reference.url)"
        case let footnote as FootnoteNode:
            return footnote.content
        case let citation as CitationNode:
            return "<cite>" + escape(citation.content) + "</cite>"
        case let citationRef as CitationReferenceNode:
            return "[\(citationRef.identifier)]"
        case let formula as FormulaNode:
            return formula.expression
        default:
            return renderChildren(node)
        }
    }

    private func renderChildren(_ node: MarkdownNodeBase) -> String {
        return node.children().map { render($0) }.joined()
    }

    private func escape(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        return result
    }

    private func escapeAttribute(_ text: String) -> String {
        var result = escape(text)
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        return result
    }
}

