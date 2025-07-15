import Foundation

/// AST node types for Markdown elements
public final class MarkdownRootNode: CodeNode {
    public init(value: String = "", range: Range<String.Index>? = nil) {
        super.init(type: MarkdownLanguage.Element.root, value: value, range: range)
    }
}

public final class MarkdownParagraphNode: CodeNode {
    public init(value: String = "", range: Range<String.Index>? = nil) {
        super.init(type: MarkdownLanguage.Element.paragraph, value: value, range: range)
    }
}

public final class MarkdownHeadingNode: CodeNode {
    public let level: Int
    public init(value: String = "", level: Int, range: Range<String.Index>? = nil) {
        self.level = level
        super.init(type: MarkdownLanguage.Element.heading, value: value, range: range)
    }
    public override var id: Int {
        var hasher = Hasher()
        hasher.combine(String(describing: type))
        hasher.combine(value)
        hasher.combine(level)
        for child in children { hasher.combine(child.id) }
        return hasher.finalize()
    }
}

public final class MarkdownTextNode: CodeNode {
    public init(value: String = "", range: Range<String.Index>? = nil) {
        super.init(type: MarkdownLanguage.Element.text, value: value, range: range)
    }
}

public final class MarkdownListItemNode: CodeNode {
    public init(value: String = "", range: Range<String.Index>? = nil) {
        super.init(type: MarkdownLanguage.Element.listItem, value: value, range: range)
    }
}

public final class MarkdownOrderedListItemNode: CodeNode {
    public init(value: String = "", range: Range<String.Index>? = nil) {
        super.init(type: MarkdownLanguage.Element.orderedListItem, value: value, range: range)
    }
}

public class MarkdownListNode: CodeNode {
    public let level: Int
    public init(type: any CodeElement, value: String = "", level: Int, range: Range<String.Index>? = nil) {
        self.level = level
        super.init(type: type, value: value, range: range)
    }
    public override var id: Int {
        var hasher = Hasher()
        hasher.combine(String(describing: type))
        hasher.combine(value)
        hasher.combine(level)
        for child in children { hasher.combine(child.id) }
        return hasher.finalize()
    }
}

public final class MarkdownUnorderedListNode: MarkdownListNode {
    public init(value: String = "", level: Int, range: Range<String.Index>? = nil) {
        super.init(type: MarkdownLanguage.Element.unorderedList, value: value, level: level, range: range)
    }
}

public final class MarkdownOrderedListNode: MarkdownListNode {
    public init(value: String = "", level: Int, range: Range<String.Index>? = nil) {
        super.init(type: MarkdownLanguage.Element.orderedList, value: value, level: level, range: range)
    }
}

public final class MarkdownEmphasisNode: CodeNode {
    public init(value: String = "", range: Range<String.Index>? = nil) {
        super.init(type: MarkdownLanguage.Element.emphasis, value: value, range: range)
    }
}

public final class MarkdownStrongNode: CodeNode {
    public init(value: String = "", range: Range<String.Index>? = nil) {
        super.init(type: MarkdownLanguage.Element.strong, value: value, range: range)
    }
}

public final class MarkdownCodeBlockNode: CodeNode {
    public init(value: String = "", range: Range<String.Index>? = nil) {
        super.init(type: MarkdownLanguage.Element.codeBlock, value: value, range: range)
    }
}

public final class MarkdownInlineCodeNode: CodeNode {
    public init(value: String = "", range: Range<String.Index>? = nil) {
        super.init(type: MarkdownLanguage.Element.inlineCode, value: value, range: range)
    }
}

public final class MarkdownLinkNode: CodeNode {
    public let text: [CodeNode]
    public let url: String

    public init(text: [CodeNode], url: String, range: Range<String.Index>? = nil) {
        self.text = text
        self.url = url
        super.init(type: MarkdownLanguage.Element.link, value: "", range: range)
        text.forEach { addChild($0) }
    }

    public override var id: Int {
        var hasher = Hasher()
        hasher.combine(String(describing: type))
        hasher.combine(url)
        for child in children { hasher.combine(child.id) }
        return hasher.finalize()
    }
}

public final class MarkdownBlockQuoteNode: CodeNode {
    public init(value: String = "", range: Range<String.Index>? = nil) {
        super.init(type: MarkdownLanguage.Element.blockQuote, value: value, range: range)
    }
}

public final class MarkdownThematicBreakNode: CodeNode {
    public init(value: String = "", range: Range<String.Index>? = nil) {
        super.init(type: MarkdownLanguage.Element.thematicBreak, value: value, range: range)
    }
}

public final class MarkdownImageNode: CodeNode {
    public let alt: String
    public let url: String

    public init(alt: String, url: String, range: Range<String.Index>? = nil) {
        self.alt = alt
        self.url = url
        super.init(type: MarkdownLanguage.Element.image, value: "", range: range)
    }

    public override var id: Int {
        var hasher = Hasher()
        hasher.combine(String(describing: type))
        hasher.combine(alt)
        hasher.combine(url)
        for child in children { hasher.combine(child.id) }
        return hasher.finalize()
    }
}

public final class MarkdownHtmlNode: CodeNode {
    public init(value: String = "", range: Range<String.Index>? = nil) {
        super.init(type: MarkdownLanguage.Element.html, value: value, range: range)
    }
}

public final class MarkdownEntityNode: CodeNode {
    public init(value: String = "", range: Range<String.Index>? = nil) {
        super.init(type: MarkdownLanguage.Element.entity, value: value, range: range)
    }
}

public final class MarkdownStrikethroughNode: CodeNode {
    public init(value: String = "", range: Range<String.Index>? = nil) {
        super.init(type: MarkdownLanguage.Element.strikethrough, value: value, range: range)
    }
}

public final class MarkdownTableNode: CodeNode {
    public init(value: String = "", range: Range<String.Index>? = nil) {
        super.init(type: MarkdownLanguage.Element.table, value: value, range: range)
    }
}

public final class MarkdownTableHeaderNode: CodeNode {
    public init(value: String = "", range: Range<String.Index>? = nil) {
        super.init(type: MarkdownLanguage.Element.tableHeader, value: value, range: range)
    }
}

public final class MarkdownTableRowNode: CodeNode {
    public init(value: String = "", range: Range<String.Index>? = nil) {
        super.init(type: MarkdownLanguage.Element.tableRow, value: value, range: range)
    }
}

public final class MarkdownTableCellNode: CodeNode {
    public init(value: String = "", range: Range<String.Index>? = nil) {
        super.init(type: MarkdownLanguage.Element.tableCell, value: value, range: range)
    }
}

public final class MarkdownAutoLinkNode: CodeNode {
    public let url: String

    public init(url: String, range: Range<String.Index>? = nil) {
        self.url = url
        super.init(type: MarkdownLanguage.Element.autoLink, value: url, range: range)
    }

    public override var id: Int {
        var hasher = Hasher()
        hasher.combine(String(describing: type))
        hasher.combine(url)
        for child in children { hasher.combine(child.id) }
        return hasher.finalize()
    }
}

public final class MarkdownLinkReferenceDefinitionNode: CodeNode {
    public init(value: String = "", range: Range<String.Index>? = nil) {
        super.init(type: MarkdownLanguage.Element.linkReferenceDefinition, value: value, range: range)
    }
}
