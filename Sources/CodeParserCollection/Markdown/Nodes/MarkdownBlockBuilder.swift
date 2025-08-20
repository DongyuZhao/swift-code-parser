import CodeParserCore
import Foundation

/// Main block-level builder that handles line-by-line processing following CommonMark spec
/// Organizes tokens into logical lines and delegates to specialized CodeNodeBuilder instances
public class MarkdownBlockBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  private let builders: [any CodeNodeBuilder<MarkdownNodeElement, MarkdownTokenElement>]

  public init() {
    self.builders = [

    ]
  }

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard context.consuming < context.tokens.count else { return false }

    // Get block state - fail if not available
    guard let blockState = context.state as? MarkdownConstructState else {
      return false
    }

    // If this is the first time, organize tokens into lines
    if blockState.lines.isEmpty {
      blockState.lines = organizeIntoLines(from: context)
      blockState.currentLineIndex = 0
    }

    guard !blockState.lines.isEmpty else { return false }

    // Process each line with appropriate node builder
    var processedAny = false
    while blockState.currentLineIndex < blockState.lines.count {
      let processed = processCurrentLine(state: blockState, context: &context)
      if processed {
        processedAny = true
      }
      blockState.currentLineIndex += 1
    }

    return processedAny
  }

  /// Organizes tokens into logical lines based on CommonMark line break rules
  private func organizeIntoLines(from context: CodeConstructContext<Node, Token>) -> [MarkdownLine] {
    var lines: [MarkdownLine] = []
    var currentLineTokens: [any CodeToken<MarkdownTokenElement>] = []
    var tokenIndex = context.consuming

    while tokenIndex < context.tokens.count {
      let token = context.tokens[tokenIndex]

      if token.element == .eof {
        // End of input - current line will be added after loop
        break
      } else if token.element == .newline {
        // End current line
        lines.append(MarkdownLine(tokens: currentLineTokens))
        currentLineTokens = []
        tokenIndex += 1
      } else {
        currentLineTokens.append(token)
        tokenIndex += 1
      }
    }

    // Add final line if tokens remain
    if !currentLineTokens.isEmpty {
      lines.append(MarkdownLine(tokens: currentLineTokens))
    }

    return lines
  }


  /// Process current line with appropriate node builder
  private func processCurrentLine(state: MarkdownConstructState, context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard state.currentLineIndex < state.lines.count else { return false }

    let currentLine = state.lines[state.currentLineIndex]

    let lineContext = CodeConstructContext<Node, Token>(current: context.current, tokens: currentLine.tokens, state: MarkdownLineState())

    // Try each builder until one handles the line
    for builder in builders {
      var tempContext = lineContext
      if builder.build(from: &tempContext) {
        // Builder handled the line, update context
        context.current = tempContext.current
        return true
      }
    }

    return false
  }
}

private class MarkdownLineState: CodeConstructState {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}
}
