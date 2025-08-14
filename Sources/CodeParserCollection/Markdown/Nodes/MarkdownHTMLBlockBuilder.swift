import CodeParserCore
import Foundation

/// Parses raw HTML blocks as specified by CommonMark.
/// Supports the seven HTML block start conditions and
/// preserves the original content verbatim.
public class MarkdownHTMLBlockBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  private enum Kind {
    case type1(String) // specific tag requiring closing tag
    case comment
    case processing
    case declaration
    case cdata
    case open
    case close
  }

  private static let blockTags: Set<String> = [
    "address", "article", "aside", "base", "basefont", "blockquote", "body",
    "caption", "center", "col", "colgroup", "dd", "details", "dialog", "dir",
    "div", "dl", "dt", "fieldset", "figcaption", "figure", "footer", "form",
    "frame", "frameset", "h1", "h2", "h3", "h4", "h5", "h6", "head", "header",
    "hr", "html", "iframe", "legend", "li", "link", "main", "menu", "menuitem",
    "meta", "nav", "noframes", "noscript", "ol", "optgroup", "option", "p",
    "param", "script", "section", "source", "style", "summary", "table", "tbody",
    "td", "tfoot", "th", "thead", "title", "tr", "track", "ul"
  ]

  public func build(from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
    guard context.current is DocumentNode else { return false }
    let tokens = context.tokens
    var idx = context.consuming
    if idx >= tokens.count { return false }

    // Require start of line
    if idx > 0, tokens[idx - 1].element != .newline { return false }

    // Leading indentation up to three spaces
    let start = idx
    let (indent, afterIndent) = consumeIndentation(tokens, start: idx)
    if indent >= 4 { return false }
    idx = afterIndent
    guard idx < tokens.count, tokens[idx].element == .lt else { return false }

    // Capture first line text for start condition detection
    var lineEnd = idx
    while lineEnd < tokens.count,
          tokens[lineEnd].element != .newline,
          tokens[lineEnd].element != .eof {
      lineEnd += 1
    }
    let firstLine = tokens[idx..<lineEnd].map { $0.text }.joined()
    let lower = firstLine.lowercased()

    // Determine block kind
    var kind: Kind?
    if lower.hasPrefix("<script") { kind = .type1("script") }
    else if lower.hasPrefix("<pre") { kind = .type1("pre") }
    else if lower.hasPrefix("<style") { kind = .type1("style") }
    else if lower.hasPrefix("<textarea") { kind = .type1("textarea") }
    else if firstLine.hasPrefix("<!--") { kind = .comment }
    else if firstLine.hasPrefix("<?") { kind = .processing }
    else if firstLine.hasPrefix("<![CDATA[") { kind = .cdata }
    else if firstLine.hasPrefix("<!") {
      let rest = firstLine.dropFirst(2)
      if let ch = rest.first, ch.isUppercase { kind = .declaration }
    } else if firstLine.hasPrefix("</") {
      let rest = firstLine.dropFirst(2)
      let name = rest.prefix { $0.isLetter || $0.isNumber || $0 == "-" }.lowercased()
      if Self.blockTags.contains(name) { kind = .close }
    } else {
      let rest = firstLine.dropFirst()
      let name = rest.prefix { $0.isLetter || $0.isNumber || $0 == "-" }.lowercased()
      if Self.blockTags.contains(name) { kind = .open }
    }
    guard let blockKind = kind else { return false }

    // Scan lines until termination condition met
    var i = idx
    var blockEnd = start
    while i < tokens.count {
      var j = i
      while j < tokens.count,
            tokens[j].element != .newline,
            tokens[j].element != .eof {
        j += 1
      }
      let line = tokens[i..<j].map { $0.text }.joined()
      let hasNewline = j < tokens.count && tokens[j].element == .newline

      var done = false
      switch blockKind {
      case .type1(let tag):
        let pattern = "</\\s*\(tag)\\s*>"
        if line.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
          blockEnd = j
          context.consuming = hasNewline ? j + 1 : j
          done = true
        }
      case .comment:
        if line.contains("-->") {
          blockEnd = j
          context.consuming = hasNewline ? j + 1 : j
          done = true
        }
      case .processing:
        if line.contains("?>") {
          blockEnd = j
          context.consuming = hasNewline ? j + 1 : j
          done = true
        }
      case .declaration:
        if line.contains(">") {
          blockEnd = j
          context.consuming = hasNewline ? j + 1 : j
          done = true
        }
      case .cdata:
        if line.contains("]]>") {
          blockEnd = j
          context.consuming = hasNewline ? j + 1 : j
          done = true
        }
      case .open, .close:
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
          blockEnd = i
          context.consuming = i
          done = true
        }
      }

      if done { break }

      if hasNewline {
        blockEnd = j + 1
        i = j + 1
      } else {
        blockEnd = j
        context.consuming = j
        break
      }
    }

    var end = blockEnd
    if end > start, tokens[end - 1].element == .newline { end -= 1 }
    let content = tokens[start..<end].map { $0.text }.joined()
    let node = HTMLBlockNode(name: "", content: content)
    context.current.append(node)
    if let state = context.state as? MarkdownConstructState { state.previousLineBlank = false }
    return true
  }
}
