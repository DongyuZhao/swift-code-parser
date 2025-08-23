import CodeParserCore
import Foundation

/// Processes strikethrough (~~text~~) following CommonMark delimiter processing strategy
/// GFM Strikethrough Extension: https://github.github.com/gfm/#strikethrough-extension-
public class MarkdownStrikethroughProcessor: MarkdownContentProcessor {
  public let delimiters: Set<Character> = ["~"]

  public init() {}

  public func process(
    _ token: any CodeToken<MarkdownTokenElement>,
    at index: Int,
    in tokens: [any CodeToken<MarkdownTokenElement>],
    context: inout MarkdownContentContext
  ) -> Bool {
    guard token.element == .punctuation,
          token.text == "~" else {
      return false
    }

    // Build delimiter run following CommonMark strategy
    let runInfo = buildDelimiterRun(startingAt: index, in: tokens)

    // Only handle exactly 2 tildes for strikethrough (GFM requirement)
    guard runInfo.length == 2 else {
      return false
    }

    // Create delimiter run and push to stack
    let delimiterRun = MarkdownDelimiterRun(
      type: .custom("strikethrough"),
      length: runInfo.length,
      openable: runInfo.canOpen,
      closable: runInfo.canClose,
      index: context.current
    )

    context.delimiters.push(delimiterRun, textNode: nil)

    // Advance past processed tokens
    context.advance(by: runInfo.length)

    return true
  }

  public func createNode(
    for delimiterType: MarkdownDelimiter,
    openerRun: MarkdownDelimiterRun,
    closerRun: MarkdownDelimiterRun,
    contentTokens: ArraySlice<any CodeToken<MarkdownTokenElement>>
  ) -> MarkdownNodeBase? {
    // Only handle strikethrough delimiters
    guard case .custom("strikethrough") = delimiterType else {
      return nil
    }

    // Check for line breaks (strikethrough cannot span line breaks)
    for token in contentTokens {
      if token.element == .newline {
        return nil
      }
    }

    // Create strikethrough node and recursively inline-parse its children
    let strikethroughNode = StrikeNode(content: "")

    let builder = MarkdownContentBuilder()
    let inner = builder.process(Array(contentTokens))
    for child in inner {
      strikethroughNode.append(child)
    }
    return strikethroughNode
  }

  // This processor supports the custom("strikethrough") delimiter
  public func supports(delimiter: MarkdownDelimiter) -> Bool {
    if case .custom(let name) = delimiter { return name == "strikethrough" }
    return false
  }

  // Reject pairs that cross newlines
  public func canPair(opener: MarkdownDelimiterRun, closer: MarkdownDelimiterRun, tokens: [any CodeToken<MarkdownTokenElement>]) -> Bool {
    let start = opener.index + opener.length
    let end = closer.index
    guard start <= end else { return false }
    for i in start..<end {
      if tokens[i].element == .newline { return false }
    }
    return true
  }

  private func buildDelimiterRun(
    startingAt index: Int,
    in tokens: [any CodeToken<MarkdownTokenElement>]
  ) -> (length: Int, canOpen: Bool, canClose: Bool) {

    var length = 0
    var currentIndex = index

    // Count consecutive tilde characters
    while currentIndex < tokens.count,
          tokens[currentIndex].element == .punctuation,
          tokens[currentIndex].text == "~" {
      length += 1
      currentIndex += 1
    }

    // For strikethrough, we use simple flanking rules
    let canOpen = !isFollowedByWhitespace(at: index, runLength: length, in: tokens)
    let canClose = !isPrecededByWhitespace(at: index, in: tokens)

    return (length: length, canOpen: canOpen, canClose: canClose)
  }

  private func isFollowedByWhitespace(at index: Int, runLength: Int, in tokens: [any CodeToken<MarkdownTokenElement>]) -> Bool {
    let afterIndex = index + runLength
    guard afterIndex < tokens.count else { return true }
    return tokens[afterIndex].element == .whitespaces
  }

  private func isPrecededByWhitespace(at index: Int, in tokens: [any CodeToken<MarkdownTokenElement>]) -> Bool {
    let beforeIndex = index - 1
    guard beforeIndex >= 0 else { return true }
    return tokens[beforeIndex].element == .whitespaces
  }

}