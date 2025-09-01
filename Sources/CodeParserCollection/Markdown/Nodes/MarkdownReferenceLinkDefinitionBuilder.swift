import CodeParserCore
import Foundation

/// Builder for reference link definitions: [id]: destination "title"
/// Uses a permissive approach during parsing, with validation handled by MarkdownEOFBuilder
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

    // Parse the basic structure: [id]:
    guard let (id, remainingTokens) = parseReferenceStart(context: context) else {
      return false
    }
    
    // Create reference node optimistically - validation will happen in MarkdownEOFBuilder
    let referenceNode = ReferenceNode(identifier: id, url: "", title: "")
    
    // Try to parse destination and title from remaining tokens on this line
    let parsed = parseDestinationAndTitle(tokens: remainingTokens)
    
    if parsed.found && !parsed.url.isEmpty {
      // Complete definition found on this line
      referenceNode.url = parsed.url
      referenceNode.title = parsed.title
      context.current.append(referenceNode)
      context.consuming = context.tokens.count
      return true
    } else {
      // Check if line has only whitespace after colon - this might be multi-line
      let remainingText = remainingTokens.map { $0.text }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
      if remainingText.isEmpty {
        // Set up pending reference for multi-line definition
        let pending = PendingReferenceDefinition(
          identifier: id, 
          referenceNode: referenceNode,
          originalLineTokens: Array(context.tokens)
        )
        state.pendingReference = pending
        context.consuming = context.tokens.count
        return true
      } else {
        // Has content but might still be valid - let EOF builder validate
        // For now, don't consume tokens and let paragraph builder handle it
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
      // Empty line - end the pending reference without destination
      context.current.append(pending.referenceNode)
      state.pendingReference = nil
      return false
    }

    // Skip indentation (up to 3 spaces for reference definitions)
    let (processedTokens, _) = stripReferenceIndentation(Array(context.tokens[startIndex...]))
    let parsed = parseDestinationAndTitle(tokens: processedTokens)
    
    var mutablePending = pending
    
    if !mutablePending.hasDestination {
      // Looking for destination
      if parsed.found && !parsed.url.isEmpty {
        // Found valid destination
        mutablePending.referenceNode.url = parsed.url
        mutablePending.referenceNode.title = parsed.title
        mutablePending.hasDestination = true
        
        if parsed.foundTitle {
          // Complete definition with both destination and title
          context.current.append(mutablePending.referenceNode)
          state.pendingReference = nil
        } else {
          // Continue looking for title
          state.pendingReference = mutablePending
        }
        context.consuming = context.tokens.count
        return true
      } else {
        // Still no destination - check if we have content that would end the reference
        let content = processedTokens.map { $0.text }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        if !content.isEmpty {
          // Non-whitespace content - end the pending reference and let this line be handled normally
          context.current.append(mutablePending.referenceNode)
          state.pendingReference = nil
          return false // Let other builders handle this line
        }
        // Keep waiting for destination (empty line)
        state.pendingReference = mutablePending
        context.consuming = context.tokens.count
        return true
      }
    } else {
      // We already have destination, looking for title
      if parsed.foundTitle {
        mutablePending.referenceNode.title = parsed.title
        mutablePending.hasTitle = true
        context.current.append(mutablePending.referenceNode)
        state.pendingReference = nil
        context.consuming = context.tokens.count
        return true
      } else {
        // Check if this might be title content without quotes
        let content = processedTokens.map { $0.text }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        if !content.isEmpty && !content.hasPrefix("[") {
          // Try to parse as a title (might be unquoted or just check for quoted)
          let titleResult = parseTitle(content)
          if !titleResult.isEmpty {
            mutablePending.referenceNode.title = titleResult
            mutablePending.hasTitle = true
            context.current.append(mutablePending.referenceNode)
            state.pendingReference = nil
            context.consuming = context.tokens.count
            return true
          }
        }
        
        // No title found or empty line - complete with current title
        context.current.append(mutablePending.referenceNode)
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
        
        if remaining.isEmpty {
          return ParseResult(found: true, url: url, title: "", foundTitle: false)
        } else {
          let title = parseTitle(remaining)
          return ParseResult(found: true, url: url, title: title, foundTitle: !title.isEmpty)
        }
      } else {
        // Unclosed < - might be invalid, but let EOF builder decide
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
  
  /// Strip leading indentation from tokens for reference definition continuation lines
  /// Reference definitions can have indentation, but we need to process the content
  private func stripReferenceIndentation(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> ([any CodeToken<MarkdownTokenElement>], Int) {
    guard !tokens.isEmpty else { return (tokens, 0) }
    
    // Check if first token is whitespace (indentation)
    if let firstToken = tokens.first as? MarkdownToken,
       firstToken.element == .whitespaces {
      // For reference definitions, we can strip any amount of leading whitespace
      // since CommonMark allows flexible indentation for continuation lines
      return (Array(tokens.dropFirst()), firstToken.text.count)
    }
    
    return (tokens, 0)
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