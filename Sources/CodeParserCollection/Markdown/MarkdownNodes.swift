import CodeParserCore
import Foundation

// MARK: - Markdown Node Element Definition
public enum MarkdownNodeElement: String, CaseIterable, CodeNodeElement {
  // MARK: - Document Structure
  case document = "document"

  // MARK: - Block Elements (CommonMark)
  case paragraph = "paragraph"
  case heading = "heading"
  case thematicBreak = "thematic_break"
  case blockquote = "blockquote"
  case orderedList = "ordered_list"
  case unorderedList = "unordered_list"
  case listItem = "list_item"
  case blankLine = "blank_line"
  case codeBlock = "code_block"
  case htmlBlock = "html_block"
  case imageBlock = "image_block"
  case definitionList = "definition_list"
  case definitionItem = "definition_item"
  case definitionTerm = "definition_term"
  case definitionDescription = "definition_description"
  case admonition = "admonition"
  case customContainer = "custom_container"

  // MARK: - Inline Elements (CommonMark)
  case text = "text"
  case emphasis = "emphasis"
  case strong = "strong"
  case strike = "striket"
  case code = "code"
  case link = "link"
  case image = "image"
  case html = "html"
  case lineBreak = "line_break"

  // MARK: - Components
  case comment = "comment"

  // MARK: - GFM Extensions
  case table = "table"
  case tableHeader = "table_header"
  case tableRow = "table_row"
  case tableCell = "table_cell"
  case taskList = "task_list"
  case taskListItem = "task_list_item"
  case reference = "reference"
  case footnote = "footnote"
  case footnoteReference = "footnote_reference"
  case citation = "citation"
  case citationReference = "citation_reference"

  // MARK: - Math Elements (LaTeX/TeX)
  case formula = "formula"
  case formulaBlock = "formula_block"
}

// MARK: - Markdown Node Base Class
/// Base class for all Markdown nodes, extending CodeNode with semantic properties
public class MarkdownNodeBase: CodeNode<MarkdownNodeElement> {
  public override init(element: MarkdownNodeElement) {
    super.init(element: element)
  }

  /// Convenience method to append a MarkdownNodeBase child
  public func append(_ child: MarkdownNodeBase) {
    super.append(child)
  }

  /// Convenience method to get children as MarkdownNodeBase
  public func children() -> [MarkdownNodeBase] {
    return children.compactMap { $0 as? MarkdownNodeBase }
  }

  /// Convenience method to get parent as MarkdownNodeBase
  public func parent() -> MarkdownNodeBase? {
    return parent as? MarkdownNodeBase
  }
}

// MARK: - Document Structure
/// Root node representing an entire Markdown document.
public class DocumentNode: MarkdownNodeBase {
  public var title: String?
  public var metadata: [String: Any] = [:]

  public init(title: String? = nil) {
    self.title = title
    super.init(element: .document)
  }

  public override func hash(into hasher: inout Hasher) {
    super.hash(into: &hasher)
    hasher.combine(title)
    // Note: metadata is [String: Any] which isn't Hashable,
    // so we hash the keys and attempt to hash string representations of values
    for (key, value) in metadata.sorted(by: { $0.key < $1.key }) {
      hasher.combine(key)
      hasher.combine(String(describing: value))
    }
  }

}

// MARK: - Block Elements
public class ParagraphNode: MarkdownNodeBase {
  public init(range: Range<String.Index>) {
    super.init(element: .paragraph)
  }

}

public class HeaderNode: MarkdownNodeBase {
  public var level: Int

  public init(level: Int) {
    self.level = level
    super.init(element: .heading)
  }

  public override func hash(into hasher: inout Hasher) {
    super.hash(into: &hasher)
    hasher.combine(level)
  }
}

public class ThematicBreakNode: MarkdownNodeBase {
  public var marker: String

  public init(marker: String = "---") {
    self.marker = marker
    super.init(element: .thematicBreak)
  }

  public override func hash(into hasher: inout Hasher) {
    super.hash(into: &hasher)
    hasher.combine(marker)
  }

}

public class BlockquoteNode: MarkdownNodeBase {
  public var level: Int

  public init(level: Int = 1) {
    self.level = level
    super.init(element: .blockquote)
  }

  public override func hash(into hasher: inout Hasher) {
    super.hash(into: &hasher)
    hasher.combine(level)
  }

}

public class ListNode: MarkdownNodeBase {
  public var level: Int

  public init(element: MarkdownNodeElement, level: Int = 1) {
    self.level = level
    super.init(element: element)
  }

  public override func hash(into hasher: inout Hasher) {
    super.hash(into: &hasher)
    hasher.combine(level)
  }
}

public class OrderedListNode: ListNode {
  public var start: Int

  public init(start: Int = 1, level: Int = 1) {
    self.start = start
    super.init(element: .orderedList, level: level)
  }

  public override func hash(into hasher: inout Hasher) {
    super.hash(into: &hasher)
    hasher.combine(start)
  }

}

public class UnorderedListNode: ListNode {
  public init(level: Int = 1) {
    super.init(element: .unorderedList, level: level)
  }

}

public class ListItemNode: MarkdownNodeBase {
  public var marker: String

  public init(marker: String) {
    self.marker = marker
    super.init(element: .listItem)
  }

  public override func hash(into hasher: inout Hasher) {
    super.hash(into: &hasher)
    hasher.combine(marker)
  }

}

public class CodeBlockNode: MarkdownNodeBase {
  public var language: String?
  public var source: String

  public init(source: String, language: String? = nil) {
    self.language = language
    self.source = source
    super.init(element: .codeBlock)
  }

  public override func hash(into hasher: inout Hasher) {
    super.hash(into: &hasher)
    hasher.combine(language)
    hasher.combine(source)
  }

}

public class HTMLBlockNode: MarkdownNodeBase {
  public var name: String
  public var content: String

  public init(name: String, content: String) {
    self.name = name
    self.content = content
    super.init(element: .htmlBlock)
  }

  public override func hash(into hasher: inout Hasher) {
    super.hash(into: &hasher)
    hasher.combine(name)
    hasher.combine(content)
  }

}

public class ImageBlockNode: MarkdownNodeBase {
  public var url: String
  public var alt: String

  public init(url: String, alt: String) {
    self.url = url
    self.alt = alt
    super.init(element: .imageBlock)
  }

  public override func hash(into hasher: inout Hasher) {
    super.hash(into: &hasher)
    hasher.combine(url)
    hasher.combine(alt)
  }

}

public class DefinitionListNode: MarkdownNodeBase {
  public init() {
    super.init(element: .definitionList)
  }

}

public class DefinitionItemNode: MarkdownNodeBase {
  public init() {
    super.init(element: .definitionItem)
  }

}

public class DefinitionTermNode: MarkdownNodeBase {
  public init() {
    super.init(element: .definitionTerm)
  }

}

public class DefinitionDescriptionNode: MarkdownNodeBase {
  public init() {
    super.init(element: .definitionDescription)
  }

}

public class AdmonitionNode: MarkdownNodeBase {
  public var kind: String

  public init(kind: String) {
    self.kind = kind
    super.init(element: .admonition)
  }

  public override func hash(into hasher: inout Hasher) {
    super.hash(into: &hasher)
    hasher.combine(kind)
  }

}

public class CustomContainerNode: MarkdownNodeBase {
  public var name: String
  public var content: String

  public init(name: String, content: String) {
    self.name = name
    self.content = content
    super.init(element: .customContainer)
  }

  public override func hash(into hasher: inout Hasher) {
    super.hash(into: &hasher)
    hasher.combine(name)
    hasher.combine(content)
  }

}

// MARK: - Inline Elements
public class TextNode: MarkdownNodeBase {
  public var content: String

  public init(content: String) {
    self.content = content
    super.init(element: .text)
  }

  public override func hash(into hasher: inout Hasher) {
    super.hash(into: &hasher)
    hasher.combine(content)
  }

}

public class EmphasisNode: MarkdownNodeBase {
  public init(content: String) {
    super.init(element: .emphasis)
  }

}

public class StrongNode: MarkdownNodeBase {
  public init(content: String) {
    super.init(element: .strong)
  }

}

public class StrikeNode: MarkdownNodeBase {
  public init(content: String) {
    super.init(element: .strike)
  }

}

public class InlineCodeNode: MarkdownNodeBase {
  public var code: String

  public init(code: String) {
    self.code = code
    super.init(element: .code)
  }

  public override func hash(into hasher: inout Hasher) {
    super.hash(into: &hasher)
    hasher.combine(code)
  }

}

public class LinkNode: MarkdownNodeBase {
  public var url: String
  public var title: String

  public init(url: String, title: String) {
    self.url = url
    self.title = title
    super.init(element: .link)
  }

  public override func hash(into hasher: inout Hasher) {
    super.hash(into: &hasher)
    hasher.combine(url)
    hasher.combine(title)
  }

}

public class ImageNode: MarkdownNodeBase {
  public var url: String
  public var alt: String

  public init(url: String, alt: String) {
    self.url = url
    self.alt = alt
    super.init(element: .image)
  }

  public override func hash(into hasher: inout Hasher) {
    super.hash(into: &hasher)
    hasher.combine(url)
    hasher.combine(alt)
  }

}

public class HTMLNode: MarkdownNodeBase {
  public var content: String

  public init(content: String) {
    self.content = content
    super.init(element: .html)
  }

  public override func hash(into hasher: inout Hasher) {
    super.hash(into: &hasher)
    hasher.combine(content)
  }

}

public class LineBreakNode: MarkdownNodeBase {
  public enum LineBreak: Hashable {
    case soft
    case hard
  }

  public var variant: LineBreak

  public init(variant: LineBreak = .soft) {
    self.variant = variant
    super.init(element: .lineBreak)
  }

  public override func hash(into hasher: inout Hasher) {
    super.hash(into: &hasher)
    hasher.combine(variant)
  }

}

// MARK: - Components
public class CommentNode: MarkdownNodeBase {
  public var content: String

  public init(content: String) {
    self.content = content
    super.init(element: .comment)
  }

  public override func hash(into hasher: inout Hasher) {
    super.hash(into: &hasher)
    hasher.combine(content)
  }

}

// MARK: - GFM Extensions
public class TableNode: MarkdownNodeBase {
  public init(range: Range<String.Index>) {
    super.init(element: .table)
  }

}

public class TableHeaderNode: MarkdownNodeBase {
  public init(range: Range<String.Index>) {
    super.init(element: .tableHeader)
  }
}

public class TableRowNode: MarkdownNodeBase {
  public var isHeader: Bool

  public init(range: Range<String.Index>, isHeader: Bool = false) {
    self.isHeader = isHeader
    super.init(element: .tableRow)
  }

  public override func hash(into hasher: inout Hasher) {
    super.hash(into: &hasher)
    hasher.combine(isHeader)
  }

}

public class TableCellNode: MarkdownNodeBase {
  public init(range: Range<String.Index>) {
    super.init(element: .tableCell)
  }

}

public class TaskListNode: MarkdownNodeBase {
  public init(range: Range<String.Index>) {
    super.init(element: .taskList)
  }
}

public class TaskListItemNode: MarkdownNodeBase {
  public var checked: Bool

  public init(checked: Bool) {
    self.checked = checked
    super.init(element: .taskListItem)
  }

  public override func hash(into hasher: inout Hasher) {
    super.hash(into: &hasher)
    hasher.combine(checked)
  }

}

public class ReferenceNode: MarkdownNodeBase {
  public var identifier: String
  public var url: String
  public var title: String

  public init(identifier: String, url: String, title: String) {
    self.identifier = identifier
    self.url = url
    self.title = title
    super.init(element: .reference)
  }

  public override func hash(into hasher: inout Hasher) {
    super.hash(into: &hasher)
    hasher.combine(identifier)
    hasher.combine(url)
    hasher.combine(title)
  }
}

public class FootnoteNode: MarkdownNodeBase {
  public var identifier: String
  public var content: String
  public var referenceText: String?

  public init(
    identifier: String, content: String, referenceText: String? = nil,
    range: Range<String.Index>
  ) {
    self.identifier = identifier
    self.content = content
    self.referenceText = referenceText
    super.init(element: .footnote)
  }

  public override func hash(into hasher: inout Hasher) {
    super.hash(into: &hasher)
    hasher.combine(identifier)
    hasher.combine(content)
    hasher.combine(referenceText)
  }
}

public class CitationNode: MarkdownNodeBase {
  public var identifier: String
  public var content: String

  public init(identifier: String, content: String) {
    self.identifier = identifier
    self.content = content
    super.init(element: .citation)
  }

  public override func hash(into hasher: inout Hasher) {
    super.hash(into: &hasher)
    hasher.combine(identifier)
    hasher.combine(content)
  }
}

public class FootnoteReferenceNode: MarkdownNodeBase {
  public var identifier: String

  public init(identifier: String) {
    self.identifier = identifier
    super.init(element: .footnoteReference)
  }

  public override func hash(into hasher: inout Hasher) {
    super.hash(into: &hasher)
    hasher.combine(identifier)
  }

}

public class CitationReferenceNode: MarkdownNodeBase {
  public var identifier: String

  public init(identifier: String) {
    self.identifier = identifier
    super.init(element: .citationReference)
  }

  public override func hash(into hasher: inout Hasher) {
    super.hash(into: &hasher)
    hasher.combine(identifier)
  }

}

// MARK: - Math Elements
public class FormulaNode: MarkdownNodeBase {
  public var expression: String

  public init(expression: String) {
    self.expression = expression
    super.init(element: .formula)
  }

  public override func hash(into hasher: inout Hasher) {
    super.hash(into: &hasher)
    hasher.combine(expression)
  }

}

public class FormulaBlockNode: MarkdownNodeBase {
  public var expression: String

  public init(expression: String) {
    self.expression = expression
    super.init(element: .formulaBlock)
  }

  public override func hash(into hasher: inout Hasher) {
    super.hash(into: &hasher)
    hasher.combine(expression)
  }
}
