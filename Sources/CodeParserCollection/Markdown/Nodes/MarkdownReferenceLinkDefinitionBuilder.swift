import CodeParserCore
import Foundation

/// Builder for reference link definitions: [id]: destination "title"
/// Supports multi-line definitions according to CommonMark spec
public class MarkdownReferenceLinkDefinitionBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard let state = context.state as? MarkdownConstructState else { return false }

    // Check if we're continuing a pending reference definition
    if let pending = state.pendingReference {
      return continuePendingReference(pending: pending, context: &context, state: state)
    }
    
    // Try to start a new reference definition
    return startNewReference(context: &context, state: state)
  }
  
  private func startNewReference(
    context: inout CodeConstructContext<Node, Token>,
    state: MarkdownConstructState
  ) -> Bool {
    let startIndex = 0
    guard startIndex < context.tokens.count else { return false }

    // Check for optional indentation (0-3 spaces only)
    var currentIndex = startIndex
    var indentationSpaces = 0

    if currentIndex < context.tokens.count,
       let token = context.tokens[currentIndex] as? MarkdownToken,
       token.element == .whitespaces {
      // Count spaces
      indentationSpaces = token.text.count
      // Reference definitions allow 0-3 spaces of indentation
      if indentationSpaces >= 4 {
        return false // Too much indentation - would be code block
      }
      currentIndex += 1
    }

    // Must have enough tokens left for [id]:
    guard currentIndex + 2 < context.tokens.count else { return false }

    // Check for '[' 
    guard currentIndex < context.tokens.count,
          let token1 = context.tokens[currentIndex] as? MarkdownToken,
          token1.element == .punctuation && token1.text == "[" else { return false }
    currentIndex += 1

    // Extract ID tokens until ']'
    let idStart = currentIndex
    var idEnd = currentIndex
    while idEnd < context.tokens.count {
      if let token = context.tokens[idEnd] as? MarkdownToken,
         token.element == .punctuation && token.text == "]" {
        break
      }
      idEnd += 1
    }

    guard idEnd < context.tokens.count else { return false }
    
    // Build identifier from tokens
    let idTokens = context.tokens[idStart..<idEnd]
    let id = idTokens.map { $0.text }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
    guard !id.isEmpty else { return false }

    currentIndex = idEnd + 1 // Skip past ']'

    // Check for ':'
    guard currentIndex < context.tokens.count,
          let colonToken = context.tokens[currentIndex] as? MarkdownToken,
          colonToken.element == .punctuation && colonToken.text == ":" else { return false }
    currentIndex += 1
    
    // Create reference node
    let referenceNode = ReferenceNode(identifier: id, url: "", title: "")
    context.current.append(referenceNode)
    
    // Try to parse destination and title from remaining tokens on this line
    let remainingTokens = Array(context.tokens[currentIndex...])
    let parsed = parseDestinationAndTitle(tokens: remainingTokens)
    
    if parsed.found {
      // Complete definition found on this line
      referenceNode.url = parsed.url
      referenceNode.title = parsed.title
      state.addReferenceDefinition(identifier: id, url: parsed.url, title: parsed.title)
      return true
    } else {
      // Check if line has only whitespace after colon - if so, continue to next line
      let remainingText = remainingTokens.map { $0.text }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
      if remainingText.isEmpty {
        // Set up pending reference to continue on next line
        let pending = PendingReferenceDefinition(identifier: id, referenceNode: referenceNode)
        state.pendingReference = pending
        return true
      } else {
        // Invalid reference definition
        return false
      }
    }
  }
  
  private func continuePendingReference(
    pending: PendingReferenceDefinition,
    context: inout CodeConstructContext<Node, Token>,
    state: MarkdownConstructState
  ) -> Bool {
    let startIndex = 0
    guard startIndex < context.tokens.count else { 
      // Empty line - complete the reference if we have destination
      if pending.hasDestination {
        state.addReferenceDefinition(identifier: pending.identifier, url: pending.referenceNode.url, title: pending.referenceNode.title)
      }
      state.pendingReference = nil
      return false
    }

    let tokens = Array(context.tokens[startIndex...])
    let parsed = parseDestinationAndTitle(tokens: tokens)
    
    var mutablePending = pending
    
    if !mutablePending.hasDestination {
      // Looking for destination
      if parsed.found && !parsed.url.isEmpty {
        mutablePending.referenceNode.url = parsed.url
        mutablePending.referenceNode.title = parsed.title
        mutablePending.hasDestination = true
        state.addReferenceDefinition(identifier: mutablePending.identifier, url: parsed.url, title: parsed.title)
        state.pendingReference = nil
        return true
      } else {
        // Still no destination - check if we have other content that would invalidate
        let content = tokens.map { $0.text }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        if !content.isEmpty {
          // Non-whitespace content that's not a valid destination
          state.pendingReference = nil
          return false
        }
        // Keep waiting for destination
        state.pendingReference = mutablePending
        return true
      }
    } else {
      // We already have destination, looking for title
      if parsed.foundTitle {
        mutablePending.referenceNode.title = parsed.title
        mutablePending.hasTitle = true
        state.addReferenceDefinition(identifier: mutablePending.identifier, url: mutablePending.referenceNode.url, title: parsed.title)
        state.pendingReference = nil
        return true
      } else {
        // No title found, complete with empty title
        state.addReferenceDefinition(identifier: mutablePending.identifier, url: mutablePending.referenceNode.url, title: "")
        state.pendingReference = nil
        return false
      }
    }
  }
  
  private struct ParseResult {
    let found: Bool
    let url: String
    let title: String
    let foundTitle: Bool
    
    init(found: Bool = false, url: String = "", title: String = "", foundTitle: Bool = false) {
      self.found = found
      self.url = url
      self.title = title
      self.foundTitle = foundTitle
    }
  }
  
  private func parseDestinationAndTitle(tokens: [any CodeToken<MarkdownTokenElement>]) -> ParseResult {
    let content = tokens.map { $0.text }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
    if content.isEmpty { 
      return ParseResult()
    }
    
    // Check for angle-bracket enclosed destination
    if content.hasPrefix("<") {
      if let closeIndex = content.firstIndex(of: ">") {
        let url = String(content[content.index(after: content.startIndex)..<closeIndex])
        let remaining = String(content[content.index(after: closeIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        let title = parseTitle(remaining)
        return ParseResult(found: true, url: url, title: title, foundTitle: !title.isEmpty)
      } else {
        return ParseResult()
      }
    } else {
      // Split URL and title
      let parts = splitUrlAndTitle(content)
      if parts.url.isEmpty {
        return ParseResult()
      }
      return ParseResult(found: true, url: parts.url, title: parts.title, foundTitle: !parts.title.isEmpty)
    }
  }
  
  private func splitUrlAndTitle(_ content: String) -> (url: String, title: String) {
    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Look for title at the end (in quotes or parentheses)
    let quoteChars: [(open: Character, close: Character)] = [("\"", "\""), ("'", "'"), ("(", ")")]
    
    for (openQuote, closeQuote) in quoteChars {
      if trimmed.hasSuffix(String(closeQuote)) {
        if openQuote == closeQuote {
          // For same quotes, find the last whitespace-delimited quoted string
          if let spaceIndex = trimmed.lastIndex(where: { $0.isWhitespace }) {
            let possibleTitle = String(trimmed[trimmed.index(after: spaceIndex)...])
            if possibleTitle.count >= 2 && possibleTitle.first == openQuote && possibleTitle.last == closeQuote {
              let url = String(trimmed[..<spaceIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
              let title = String(possibleTitle.dropFirst().dropLast())
              return (url, title)
            }
          }
        } else {
          // Different open/close quotes
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
    
    // No title found - the entire content is the URL
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