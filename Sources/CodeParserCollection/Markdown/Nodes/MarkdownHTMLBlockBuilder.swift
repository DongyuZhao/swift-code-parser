import CodeParserCore
import Foundation

/// Handles HTML blocks according to CommonMark specification (all 7 types)
/// CommonMark Spec: https://spec.commonmark.org/0.31.2/#html-blocks
public class MarkdownHTMLBlockBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard let state = context.state as? MarkdownConstructState else { return false }
    guard !context.tokens.isEmpty else { return false }

    // In phased pipeline, builders receive the suffix tokens; always start at local 0
    let startIndex = 0
    guard startIndex < context.tokens.count else { return false }

    // If we have an open HTML block, handle content continuation
    if let openHTML = state.openHTMLBlock {
      return handleHTMLBlockContent(openHTML: openHTML, context: &context, state: state)
    }

    // Reconstruct the raw line (excluding trailing newline)
    var line = ""
    for t in context.tokens {
      if t.element == .newline { break }
      switch t.element {
      case .characters, .punctuation, .whitespaces, .charef:
        line += t.text
      default:
        break
      }
    }

    let trimmed = line.trimmingCharacters(in: .whitespaces)
    
    // Check for HTML block types (1-7 per CommonMark spec)
    guard let htmlType = detectHTMLBlockType(line: trimmed) else { return false }

    // HTML blocks can interrupt paragraphs
    if context.current.element == .paragraph, let parent = context.current.parent {
      context.current = parent
    }

    // Place at document level if inside container structures (HTML blocks break out of containers)
    if isInsideContainer(context: context) {
      context.current = findDocumentLevel(context: context)
    }

    // For type 2-5 (closed on same line), create simple HTML block
    if htmlType.closedOnSameLine {
      let html = HTMLBlockNode(name: htmlType.name, content: trimmed)
      context.current.append(html)
      return true
    }

    // For type 1, 6, 7 (multi-line), start HTML block and set state
    let html = HTMLBlockNode(name: htmlType.name, content: line + "\n")
    context.current.append(html)
    
    // Set state to continue collecting HTML content
    state.openHTMLBlock = OpenHTMLBlockInfo(
      type: htmlType.type,
      endCondition: htmlType.endCondition,
      htmlBlock: html
    )

    return true
  }

  private func isInsideContainer(context: CodeConstructContext<Node, Token>) -> Bool {
    var current: MarkdownNodeBase? = context.current as? MarkdownNodeBase
    while let node = current {
      if node is BlockquoteNode || node is ListItemNode || node is ListNode {
        return true
      }
      current = node.parent()
    }
    return false
  }

  private func findDocumentLevel(context: CodeConstructContext<Node, Token>) -> CodeNode<MarkdownNodeElement> {
    var current = context.current
    while let parent = current.parent {
      if let markdownParent = parent as? MarkdownNodeBase,
         !(markdownParent is BlockquoteNode) && !(markdownParent is ListItemNode) && !(markdownParent is ListNode) {
        return parent
      }
      current = parent
    }
    return current
  }
  
  /// Handles content for an already open HTML block
  private func handleHTMLBlockContent(
    openHTML: OpenHTMLBlockInfo,
    context: inout CodeConstructContext<Node, Token>,
    state: MarkdownConstructState
  ) -> Bool {
    // Reconstruct the raw line (including newline)
    var line = ""
    for t in context.tokens {
      switch t.element {
      case .characters, .punctuation, .whitespaces, .charef, .newline:
        line += t.text
      default:
        break
      }
    }
    
    // Check if this line ends the HTML block
    if let endCondition = openHTML.endCondition {
      if line.contains(endCondition) {
        // Add this line to the HTML block content and close it
        openHTML.htmlBlock.content += line
        state.openHTMLBlock = nil
        return true
      }
    } else {
      // For type 6 and 7, HTML blocks end at blank line
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.isEmpty {
        // Blank line ends the HTML block (don't include the blank line)
        state.openHTMLBlock = nil
        return false // Let other builders handle the blank line
      }
    }
    
    // Add line to HTML block content
    openHTML.htmlBlock.content += line
    return true
  }
  
  /// Detects HTML block type according to CommonMark specification
  private func detectHTMLBlockType(line: String) -> HTMLBlockTypeInfo? {
    let lowercaseLine = line.lowercased()
    
    // Type 1: <script>, <pre>, <style> (case insensitive, until closing tag)
    let type1Tags = ["<script", "<pre", "<style"]
    for tag in type1Tags {
      if lowercaseLine.hasPrefix(tag) && (lowercaseLine.count == tag.count || 
          (lowercaseLine.count > tag.count && 
           (lowercaseLine.dropFirst(tag.count).first?.isWhitespace == true || 
            lowercaseLine.dropFirst(tag.count).first == ">"))) {
        let tagName = String(tag.dropFirst())
        return HTMLBlockTypeInfo(type: 1, name: tagName, closedOnSameLine: false, endCondition: "</\(tagName)>")
      }
    }
    
    // Type 2: HTML comments <!-- to -->
    if line.hasPrefix("<!--") {
      if line.hasSuffix("-->") && line.count > 7 { // Has both start and end
        return HTMLBlockTypeInfo(type: 2, name: "comment", closedOnSameLine: true)
      } else {
        return HTMLBlockTypeInfo(type: 2, name: "comment", closedOnSameLine: false, endCondition: "-->")
      }
    }
    
    // Type 3: Processing instructions <? to ?>
    if line.hasPrefix("<?") {
      if line.hasSuffix("?>") && line.count > 4 {
        return HTMLBlockTypeInfo(type: 3, name: "pi", closedOnSameLine: true)
      } else {
        return HTMLBlockTypeInfo(type: 3, name: "pi", closedOnSameLine: false, endCondition: "?>")
      }
    }
    
    // Type 4: Declarations <!LETTER to >
    if line.hasPrefix("<!") && line.count > 2 {
      let thirdChar = line.dropFirst(2).first
      if let char = thirdChar, char.isLetter && char.isUppercase {
        if line.hasSuffix(">") {
          return HTMLBlockTypeInfo(type: 4, name: "decl", closedOnSameLine: true)
        } else {
          return HTMLBlockTypeInfo(type: 4, name: "decl", closedOnSameLine: false, endCondition: ">")
        }
      }
    }
    
    // Type 5: CDATA <![CDATA[ to ]]>
    if line.hasPrefix("<![CDATA[") {
      if line.hasSuffix("]]>") && line.count > 12 {
        return HTMLBlockTypeInfo(type: 5, name: "cdata", closedOnSameLine: true)
      } else {
        return HTMLBlockTypeInfo(type: 5, name: "cdata", closedOnSameLine: false, endCondition: "]]>")
      }
    }
    
    // Type 6: Specific HTML tags (address, article, aside, etc.)
    let type6Tags = [
      "address", "article", "aside", "base", "basefont", "blockquote", "body",
      "caption", "center", "col", "colgroup", "dd", "details", "dialog", "dir",
      "div", "dl", "dt", "fieldset", "figcaption", "figure", "footer", "form",
      "frame", "frameset", "h1", "h2", "h3", "h4", "h5", "h6", "head", "header",
      "hr", "html", "iframe", "legend", "li", "link", "main", "menu", "menuitem",
      "nav", "noframes", "ol", "optgroup", "option", "p", "param", "section",
      "source", "summary", "table", "tbody", "td", "tfoot", "th", "thead", "title",
      "tr", "track", "ul"
    ]
    
    if let match = type6Tags.first(where: { tag in
      let openTag = "<\(tag)"
      let closeTag = "</\(tag)"
      return (lowercaseLine.hasPrefix(openTag) && 
              (lowercaseLine.count == openTag.count || 
               (lowercaseLine.count > openTag.count && 
                (lowercaseLine.dropFirst(openTag.count).first?.isWhitespace == true || 
                 lowercaseLine.dropFirst(openTag.count).first == ">")))) ||
             (lowercaseLine.hasPrefix(closeTag) && 
              (lowercaseLine.count == closeTag.count || 
               (lowercaseLine.count > closeTag.count && 
                (lowercaseLine.dropFirst(closeTag.count).first?.isWhitespace == true || 
                 lowercaseLine.dropFirst(closeTag.count).first == ">"))))
    }) {
      return HTMLBlockTypeInfo(type: 6, name: match, closedOnSameLine: false)
    }
    
    // Type 7: General HTML tag (opening or closing tag followed by whitespace or end of line)
    if line.hasPrefix("<") {
      // Simple regex-like check for valid HTML tag
      let tagPattern = try? NSRegularExpression(pattern: "^</?[a-zA-Z][a-zA-Z0-9-]*(?:\\s|>|$)", options: [])
      let range = NSRange(location: 0, length: line.count)
      if tagPattern?.firstMatch(in: line, options: [], range: range) != nil {
        return HTMLBlockTypeInfo(type: 7, name: "generic", closedOnSameLine: false)
      }
    }
    
    return nil
  }
}
