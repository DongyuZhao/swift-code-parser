import CodeParserCore
import Foundation

/// Handles ATX headings (# through ######)
/// CommonMark Spec: https://spec.commonmark.org/0.31.2/#atx-headings
public class MarkdownATXHeadingBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
  guard context.state is MarkdownConstructState else {
      return false
    }

  // In phased pipeline, builders receive the suffix tokens; always start at local 0
  let startIndex = 0
    guard startIndex < context.tokens.count else {
      return false
    }

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
          // Tab counts as up to 4 spaces for indentation
          indentationSpaces += 4
        }
      }

      // ATX headings allow 0-3 spaces of indentation
      // 4 or more spaces creates an indented code block instead
      if indentationSpaces >= 4 {
        return false
      }

      // Move past the whitespace token
      currentIndex += 1
    }

    // Check for opening hash sequence
    var hashCount = 0

    // Count consecutive # characters
  while currentIndex < context.tokens.count,
      context.tokens[currentIndex].element == .punctuation,
      context.tokens[currentIndex].text == "#" {
      hashCount += 1
      currentIndex += 1

      // ATX headings support levels 1-6 only
      if hashCount > 6 {
        return false
      }
    }

    // Must have at least one # and at most 6
    guard hashCount >= 1 && hashCount <= 6 else {
      return false
    }

    // Check what follows the hashes
    if currentIndex >= context.tokens.count {
      // End of line - valid heading with empty content
    } else if context.tokens[currentIndex].element == .newline {
      // Newline after hashes - valid empty heading
    } else if context.tokens[currentIndex].element == .whitespaces {
      // Space after hashes - consume it
      currentIndex += 1
    } else {
      // No space and not end of line - not a valid ATX heading
      return false
    }

    // If we're in a paragraph context, close it first (ATX headings can interrupt paragraphs)
    if context.current.element == .paragraph {
      if let parent = context.current.parent {
        context.current = parent
      }
    }

    // Create heading node
    let heading = HeaderNode(level: hashCount)
    context.current.append(heading)

    // Collect content tokens (everything after opening sequence, excluding newline)
    var contentTokens: [any CodeToken<MarkdownTokenElement>] = []

    // Find end of content (before newline or EOF)
    var contentEnd = context.tokens.count
    for i in currentIndex..<context.tokens.count {
      if context.tokens[i].element == .newline {
        contentEnd = i
        break
      }
    }

    if currentIndex < contentEnd {
      let remainingTokens = Array(context.tokens[currentIndex..<contentEnd])

      // Look for trailing hash sequence (optional closing)
      // First skip any trailing whitespace
      var endIndex = remainingTokens.count
      while endIndex > 0 && remainingTokens[endIndex - 1].element == .whitespaces {
        endIndex -= 1
      }

      // Then look for trailing # characters
      var trailingHashStart = endIndex
      while trailingHashStart > 0,
            remainingTokens[trailingHashStart - 1].element == .punctuation,
            remainingTokens[trailingHashStart - 1].text == "#" {
        trailingHashStart -= 1
      }

      // If we found trailing hashes, check if they're preceded by whitespace or at start
      if trailingHashStart < endIndex {
        if trailingHashStart == 0 {
          // All remaining content is hashes - empty heading
          contentTokens = []
        } else if remainingTokens[trailingHashStart - 1].element == .whitespaces {
          // Whitespace before trailing hashes - remove the whitespace and hashes
          contentTokens = Array(remainingTokens[0..<(trailingHashStart - 1)])
        } else {
          // No whitespace before hashes - they're part of content, include everything up to endIndex
          contentTokens = Array(remainingTokens[0..<endIndex])
        }
      } else {
        // No trailing hashes, but strip trailing whitespace
        contentTokens = Array(remainingTokens[0..<endIndex])
      }
    }

    // Add content to heading
    if !contentTokens.isEmpty {
      let contentNode = ContentNode(tokens: contentTokens)
      heading.append(contentNode)
    }

    return true
  }
}