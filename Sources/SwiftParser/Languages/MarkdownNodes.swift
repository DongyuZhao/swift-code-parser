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
    public let lang: String?

    public var content: String {
        get { value }
        set { value = newValue }
    }

    public init(lang: String? = nil, content: String = "", range: Range<String.Index>? = nil) {
        self.lang = lang
        super.init(type: MarkdownLanguage.Element.codeBlock, value: content, range: range)
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
    public let closed: Bool

    public init(value: String = "", closed: Bool = false, range: Range<String.Index>? = nil) {
        self.closed = closed
        super.init(type: MarkdownLanguage.Element.html, value: value, range: range)
    }

    public override var id: Int {
        var hasher = Hasher()
        hasher.combine(String(describing: type))
        hasher.combine(value)
        hasher.combine(closed)
        for child in children { hasher.combine(child.id) }
        return hasher.finalize()
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
    public let identifier: String
    public let url: String

    public init(identifier: String, url: String, range: Range<String.Index>? = nil) {
        self.identifier = identifier
        self.url = url
        super.init(type: MarkdownLanguage.Element.linkReferenceDefinition, value: "", range: range)
    }

    public override var id: Int {
        var hasher = Hasher()
        hasher.combine(String(describing: type))
        hasher.combine(identifier)
        hasher.combine(url)
        for child in children { hasher.combine(child.id) }
        return hasher.finalize()
    }
}

public final class MarkdownFootnoteDefinitionNode: CodeNode {
    public let identifier: String
    public let text: String

    public init(identifier: String, text: String, range: Range<String.Index>? = nil) {
        self.identifier = identifier
        self.text = text
        super.init(type: MarkdownLanguage.Element.footnoteDefinition, value: "", range: range)
    }

    public override var id: Int {
        var hasher = Hasher()
        hasher.combine(String(describing: type))
        hasher.combine(identifier)
        hasher.combine(text)
        for child in children { hasher.combine(child.id) }
        return hasher.finalize()
    }
}

public final class MarkdownFootnoteReferenceNode: CodeNode {
    public let identifier: String

    public init(identifier: String, range: Range<String.Index>? = nil) {
        self.identifier = identifier
        super.init(type: MarkdownLanguage.Element.footnoteReference, value: "", range: range)
    }

    public override var id: Int {
        var hasher = Hasher()
        hasher.combine(String(describing: type))
        hasher.combine(identifier)
        for child in children { hasher.combine(child.id) }
        return hasher.finalize()
    }
}

public final class MarkdownFormulaBlockNode: CodeNode {
    public init(value: String = "", range: Range<String.Index>? = nil) {
        super.init(type: MarkdownLanguage.Element.formulaBlock, value: value, range: range)
    }
}
