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
    // Only proceed if we can either complete it on this line or are confident it will succeed
    return startNewReference(context: &context, state: state)
  }
  
  private func startNewReference(
    context: inout CodeConstructContext<Node, Token>,
    state: MarkdownConstructState
  ) -> Bool {
    let startIndex = 0
    guard startIndex < context.tokens.count else { return false }

    // Parse the basic structure: [id]:
    guard let (id, remainingTokens) = parseReferenceStart(context: context) else {
      return false
    }
    
    // Try to parse destination and title from remaining tokens on this line
    let parsed = parseDestinationAndTitle(tokens: remainingTokens)
    
    if parsed.found {
      // Complete definition found on this line - create the reference node
      let referenceNode = ReferenceNode(identifier: id, url: parsed.url, title: parsed.title)
      context.current.append(referenceNode)
      state.addReferenceDefinition(identifier: id, url: parsed.url, title: parsed.title)
      return true
    } else {
      // Check if line has only whitespace after colon
      let remainingText = remainingTokens.map { $0.text }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
      if remainingText.isEmpty {
        // This might be a multi-line reference definition
        // TODO: Look ahead to next line to see if it has a valid destination
        // For now, be conservative and only handle single-line definitions
        return false
      } else {
        // Has content but not a valid destination - this is not a valid reference definition
        return false
      }
    }
  }
  
  private func parseReferenceStart(context: CodeConstructContext<Node, Token>) -> (String, [any CodeToken<MarkdownTokenElement>])? {
    let startIndex = 0
    guard startIndex < context.tokens.count else { return nil }

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
        return nil // Too much indentation - would be code block
      }
      currentIndex += 1
    }

    // Must have enough tokens left for [id]:
    guard currentIndex + 2 < context.tokens.count else { return nil }

    // Check for '[' 
    guard currentIndex < context.tokens.count,
          let token1 = context.tokens[currentIndex] as? MarkdownToken,
          token1.element == .punctuation && token1.text == "[" else { return nil }
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

    guard idEnd < context.tokens.count else { return nil }
    
    // Build identifier from tokens
    let idTokens = context.tokens[idStart..<idEnd]
    let id = idTokens.map { $0.text }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
    guard !id.isEmpty else { return nil }

    currentIndex = idEnd + 1 // Skip past ']'

    // Check for ':'
    guard currentIndex < context.tokens.count,
          let colonToken = context.tokens[currentIndex] as? MarkdownToken,
          colonToken.element == .punctuation && colonToken.text == ":" else { return nil }
    currentIndex += 1
    
    // Return the ID and remaining tokens
    let remainingTokens = Array(context.tokens[currentIndex...])
    return (id, remainingTokens)
  }
  
  private func continuePendingReference(
    pending: PendingReferenceDefinition,
    context: inout CodeConstructContext<Node, Token>,
    state: MarkdownConstructState
  ) -> Bool {
    let startIndex = 0
    guard startIndex < context.tokens.count else { 
      // Empty line - this invalidates the reference definition since we don't have a destination yet
      state.pendingReference = nil
      return false
    }

    let tokens = Array(context.tokens[startIndex...])
    let parsed = parseDestinationAndTitle(tokens: tokens)
    
    var mutablePending = pending
    
    if !mutablePending.hasDestination {
      // Looking for destination
      if parsed.found && !parsed.url.isEmpty {
        // Found valid destination - now we can create the reference node
        mutablePending.referenceNode.url = parsed.url
        mutablePending.referenceNode.title = parsed.title
        mutablePending.hasDestination = true
        
        // Add the reference node to the AST
        context.current.append(mutablePending.referenceNode)
        
        // Store the reference definition
        state.addReferenceDefinition(identifier: mutablePending.identifier, url: parsed.url, title: parsed.title)
        state.pendingReference = nil
        return true
      } else {
        // Still no destination - check if we have other content that would invalidate
        let content = tokens.map { $0.text }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        if !content.isEmpty {
          // Non-whitespace content that's not a valid destination - invalidate the reference
          state.pendingReference = nil
          return false
        }
        // Keep waiting for destination (empty line)
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
    
    // Check if content starts with [ - this means it's likely another reference, not a destination
    if content.hasPrefix("[") {
      return ParseResult()
    }
    
    // Check for angle-bracket enclosed destination
    if content.hasPrefix("<") {
      if let closeIndex = content.firstIndex(of: ">") {
        let url = String(content[content.index(after: content.startIndex)..<closeIndex])
        let remaining = String(content[content.index(after: closeIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate that there's either nothing after > or valid title
        if remaining.isEmpty {
          return ParseResult(found: true, url: url, title: "", foundTitle: false)
        } else {
          let title = parseTitle(remaining)
          if !title.isEmpty || isValidTitleFormat(remaining) {
            return ParseResult(found: true, url: url, title: title, foundTitle: !title.isEmpty)
          } else {
            // Invalid content after >
            return ParseResult()
          }
        }
      } else {
        // Unclosed < is invalid
        return ParseResult()
      }
    } else {
      // Split URL and title
      let parts = splitUrlAndTitle(content)
      if parts.url.isEmpty {
        return ParseResult()
      }
      
      // Additional validation for bare URLs
      if parts.url.hasPrefix("[") {
        // URLs can't start with [ (that would be a reference)
        return ParseResult()
      }
      
      // Check for invalid characters or malformed content
      if parts.url.contains(" ") && !parts.url.hasPrefix("\"") && !parts.url.hasPrefix("'") {
        // URLs can't contain unescaped spaces unless they're quoted
        return ParseResult()
      }
      
      return ParseResult(found: true, url: parts.url, title: parts.title, foundTitle: !parts.title.isEmpty)
    }
  }
  
  private func isValidTitleFormat(_ content: String) -> Bool {
    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
    return (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
           (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) ||
           (trimmed.hasPrefix("(") && trimmed.hasSuffix(")"))
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