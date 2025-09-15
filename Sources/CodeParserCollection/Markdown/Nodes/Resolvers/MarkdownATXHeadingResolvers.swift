import CodeParserCore
import Foundation

// MARK: - ATX Heading: Creation Resolver
/// Detects an ATX heading line and creates a HeaderNode(level:), without attaching content.
public class MarkdownATXHeadingCreationResolver: MarkdownBlockResolver {
  public init() {}

  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    // ATX headings cannot start inside code blocks
    guard context.current.element != .codeBlock else { return false }

    let tokens = context.tokens
    guard !tokens.isEmpty else { return false }

    var i = 0
    // Optional indentation up to 3 spaces
    if i < tokens.count, tokens[i].element == .whitespaces {
      let ws = tokens[i].text
      let spaceCount = ws.reduce(0) { $0 + ($1 == " " ? 1 : 0) }
      if spaceCount > 3 { return false }
      i += 1
    }

    // Count leading '#'
    var level = 0
    while i < tokens.count, tokens[i].element == .punctuation, tokens[i].text == "#" {
      level += 1
      if level > 6 { break }
      i += 1
    }
    guard level >= 1 && level <= 6 else { return false }

    // Next must be whitespace or EOL
    if i >= tokens.count { return false }
    if tokens[i].element == .newline || tokens[i].element == .eof {
      // Empty heading
      if let parent = context.current as? MarkdownNodeBase {
        parent.append(HeaderNode(level: level))
        return true
      }
      return false
    }

    guard tokens[i].element == .whitespaces else { return false }

    // Create the heading node; content is handled in construction phase
    if let parent = context.current as? MarkdownNodeBase {
      let header = HeaderNode(level: level)
      parent.append(header)
      // Make the new header the current container for construction phase
      context.current = header
      return true
    }
    return false
  }
}

// MARK: - ATX Heading: Continuation Resolver
/// ATX headings are single-line blocks and do not continue; this always returns false.
public class MarkdownATXHeadingContinuationResolver: MarkdownBlockResolver {
  public init() {}

  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    // Ignore EOF-only line; block builder emits it as its own line
    if context.tokens.count == 1, context.tokens.first?.element == .eof { return false }

    // ATX headings do not continue across lines. If current is a heading,
    // move current back to its parent so subsequent creation can proceed.
    if context.current.element == .heading, let parent = context.current.parent {
      context.current = parent
      return true
    }
    return false
  }
}

// MARK: - ATX Heading: Construction Resolver
/// Attaches inline content tokens to the heading created in the creation phase,
/// by appending a ContentNode to the most recently created HeaderNode.
public class MarkdownATXHeadingConstructionResolver: MarkdownBlockResolver {
  public init() {}

  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    // Find the most recent child; if it's a HeaderNode, attach content
    guard let heading = context.current as? MarkdownNodeBase, heading.element == .heading else {
      return false
    }

    let tokens = context.tokens
    var i = 0
    // Skip optional indent
    if i < tokens.count, tokens[i].element == .whitespaces {
      let ws = tokens[i].text
      let spaceCount = ws.reduce(0) { $0 + ($1 == " " ? 1 : 0) }
      if spaceCount <= 3 { i += 1 }
    }

    // Skip leading hashes (up to 6)
    var seen = 0
    while i < tokens.count, tokens[i].element == .punctuation, tokens[i].text == "#" {
      seen += 1
      if seen > 6 { break }
      i += 1
    }
    guard seen >= 1 && seen <= 6 else { return false }

    // If immediate EOL -> no content
    if i >= tokens.count || tokens[i].element == .newline || tokens[i].element == .eof {
      return true
    }

    // Require a space before content per ATX rules
    guard tokens[i].element == .whitespaces else { return false }
    i += 1

    // Determine content range including trailing newline/eof tokens
    // First, find the last non-newline/eof for trimming trailing '#' patterns
    var endContent = tokens.count - 1
    while endContent >= i, (tokens[endContent].element == .newline || tokens[endContent].element == .eof) {
      endContent -= 1
    }
    if endContent < i { endContent = i - 1 }

    // Trim trailing spaces and optional trailing # run on the content part
    while endContent >= i, tokens[endContent].element == .whitespaces { endContent -= 1 }
    var j = endContent
    var trailingHashes = 0
    while j >= i, tokens[j].element == .punctuation, tokens[j].text == "#" {
      trailingHashes += 1
      j -= 1
    }
    if trailingHashes > 0 {
      // Determine if there is any non-space content before the trailing run
      var k = j
      while k >= i, tokens[k].element == .whitespaces { k -= 1 }
      let onlySpacesBeforeRun = (k < i)

      // Closing sequence valid if immediately preceded by whitespace OR if there is no content
      if (j >= i && tokens[j].element == .whitespaces) || onlySpacesBeforeRun {
        while j >= i, tokens[j].element == .whitespaces { j -= 1 }
        endContent = j
      }
      // else: do not trim; hashes are part of content
    }

    // Build final slice: trimmed content tokens only (no newline/eof in ATX heading content)
    var contentTokens: [any CodeToken<MarkdownTokenElement>] = []
    if endContent >= i {
      contentTokens.append(contentsOf: tokens[i...endContent])
    }

    if !contentTokens.isEmpty {
      heading.append(ContentNode(tokens: contentTokens))
    }
    return true
  }
}
