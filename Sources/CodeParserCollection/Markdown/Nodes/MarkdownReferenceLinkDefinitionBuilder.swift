import CodeParserCore
import Foundation

/// Builder for reference link definitions: [id]: destination "title"
public class MarkdownReferenceLinkDefinitionBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard context.state is MarkdownConstructState else { return false }

    // In phased pipeline, builders receive the suffix tokens; always start at local 0
    let startIndex = 0
    guard startIndex < context.tokens.count else { return false }

    // Check for optional indentation (0-3 spaces only)
    var currentIndex = startIndex
    var indentationSpaces = 0

    if currentIndex < context.tokens.count,
       context.tokens[currentIndex].element == .whitespaces {
      // Count spaces in the whitespace token
      for char in context.tokens[currentIndex].text {
        if char == " " {
          indentationSpaces += 1
        } else if char == "\t" {
          indentationSpaces += 4
        }
        if indentationSpaces >= 4 {
          return false // Too much indentation
        }
      }
      currentIndex += 1
    }

    // Must have enough tokens left for [id]:
    guard currentIndex + 2 < context.tokens.count else { return false }

    // Check for '[' punctuation
    guard context.tokens[currentIndex].element == .punctuation,
          context.tokens[currentIndex].text == "[" else { return false }
    currentIndex += 1

    // Extract ID
    let idStart = currentIndex
    var idEnd = currentIndex
    while idEnd < context.tokens.count,
          !(context.tokens[idEnd].element == .punctuation && context.tokens[idEnd].text == "]") {
      idEnd += 1
    }

    guard idEnd < context.tokens.count else { return false }
    let id = context.tokens[idStart..<idEnd].map { $0.text }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
    guard !id.isEmpty else { return false }

    currentIndex = idEnd + 1 // Skip past ']'

    // Check for ':'
    guard currentIndex < context.tokens.count,
          context.tokens[currentIndex].element == .punctuation,
          context.tokens[currentIndex].text == ":" else { return false }
    currentIndex += 1

    // Parse destination and title from remaining tokens
    let remaining = context.tokens[currentIndex...].map { $0.text }.joined()
    let (url, title) = parseDestinationAndTitle(remaining.trimmingCharacters(in: .whitespacesAndNewlines))

    // Create ReferenceNode
    let referenceNode = ReferenceNode(
      identifier: id,
      url: url,
      title: title
    )

    // Add to current container
    context.current.append(referenceNode)
    
    // Store reference definition in construct state for later resolution
    if let markdownState = context.state as? MarkdownConstructState {
      markdownState.addReferenceDefinition(identifier: id, url: url, title: title)
    }

    return true
  }
  
  private func parseDestinationAndTitle(_ content: String) -> (url: String, title: String) {
    if content.isEmpty { return ("", "") }
    
    var url = ""
    var title = ""
    
    // Handle angle-bracket enclosed destination
    if content.hasPrefix("<") {
      if let closeIndex = content.firstIndex(of: ">") {
        url = String(content[content.index(after: content.startIndex)..<closeIndex])
        let remaining = String(content[content.index(after: closeIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        title = parseTitle(remaining)
      } else {
        url = content
      }
    } else {
      // Find where URL ends and title begins
      let parts = splitUrlAndTitle(content)
      url = parts.url
      title = parts.title
    }
    
    return (url, title)
  }
  
  private func splitUrlAndTitle(_ content: String) -> (url: String, title: String) {
    // Look for title at the end (in quotes or parentheses)
    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Check if content ends with a quoted title
    let quoteChars: [(open: Character, close: Character)] = [("\"", "\""), ("'", "'"), ("(", ")")]
    
    for (openQuote, closeQuote) in quoteChars {
      if trimmed.hasSuffix(String(closeQuote)) {
        // For same quotes (like " "), we need to find the matching opening quote
        // For different quotes (like ( )), we can use lastIndex
        
        if openQuote == closeQuote {
          // Find the last whitespace-delimited quoted string
          if let spaceIndex = trimmed.lastIndex(where: { $0.isWhitespace }) {
            let possibleTitle = String(trimmed[trimmed.index(after: spaceIndex)...])
            if possibleTitle.count >= 2 && possibleTitle.first == openQuote && possibleTitle.last == closeQuote {
              let url = String(trimmed[..<spaceIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
              let title = String(possibleTitle.dropFirst().dropLast())
              return (url, title)
            }
          }
        } else {
          // Different open/close quotes - use lastIndex approach
          if let lastOpenIndex = trimmed.lastIndex(of: openQuote) {
            let beforeQuote = String(trimmed[..<lastOpenIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let titlePart = String(trimmed[lastOpenIndex...])
            
            if titlePart.count >= 2 && titlePart.first == openQuote && titlePart.last == closeQuote {
              let title = String(titlePart.dropFirst().dropLast())
              return (beforeQuote, title)
            }
          }
        }
      }
    }
    
    // No title found
    return (trimmed, "")
  }
  
  private func parseTitle(_ content: String) -> String {
    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return "" }
    
    // Check for quoted title
    if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
       (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) ||
       (trimmed.hasPrefix("(") && trimmed.hasSuffix(")")) {
      return String(trimmed.dropFirst().dropLast())
    }
    
    return ""
  }
}