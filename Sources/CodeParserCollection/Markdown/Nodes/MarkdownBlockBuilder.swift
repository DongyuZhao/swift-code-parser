import CodeParserCore
import Foundation

/// Main block-level builder that handles line-by-line processing following CommonMark - GFM spec
/// Organizes tokens into logical lines and delegates to specialized CodeNodeBuilder instances
public class MarkdownBlockBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  private let builders: [any CodeNodeBuilder<MarkdownNodeElement, MarkdownTokenElement>]

  public init() {
    self.builders = [
      // Order is important - more specific builders should come first
      MarkdownEOFBuilder(), // EOF should be checked first
      MarkdownATXHeadingBuilder(),
      MarkdownThematicBreakBuilder(),
      MarkdownSetextHeadingBuilder(),
      MarkdownBlockQuoteBuilder(),
      MarkdownIndentedCodeBlockBuilder(),
      MarkdownParagraphBuilder(), // Paragraph should be last as it's the fallback
    ]
  }

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard context.consuming < context.tokens.count else {
      return false
    }

    guard let state = context.state as? MarkdownConstructState else {
      // If no state is available, we cannot process block-level nodes
      return false
    }

    // If this is the first time, organize tokens into lines
    if state.lines.isEmpty {
      state.lines = lines(from: context)
    }

    guard !state.lines.isEmpty else { return false }

    var processed = false
    for line in state.lines {
      if process(line: line, context: &context) {
        processed = true
      }
    }

    // Consume all tokens since we processed all lines
    context.consuming = context.tokens.count

    return processed
  }

  /// Organizes tokens into logical lines based on CommonMark line break rules
  private func lines(from context: CodeConstructContext<Node, Token>) -> [MarkdownLine] {
    var lines: [MarkdownLine] = []
    var currentLineTokens: [any CodeToken<MarkdownTokenElement>] = []
    var tokenIndex = context.consuming

    while tokenIndex < context.tokens.count {
      let token = context.tokens[tokenIndex]

      if token.element == .eof {
        // Handle EOF: if not after newline, insert newline and treat EOF as blank line
        if !currentLineTokens.isEmpty {
          // Add current line with synthetic newline
          currentLineTokens.append(
            MarkdownToken(element: .newline, text: token.text, range: token.range))
          lines.append(MarkdownLine(tokens: currentLineTokens))
        }
        // Add empty line for EOF
        lines.append(MarkdownLine(tokens: []))
        break
      } else if token.element == .newline {
        // Include newline token at end of line and preserve empty lines
        currentLineTokens.append(token)
        lines.append(MarkdownLine(tokens: currentLineTokens))
        currentLineTokens = []
        tokenIndex += 1
      } else {
        currentLineTokens.append(token)
        tokenIndex += 1
      }
    }

    return lines
  }

  /// Process current line with appropriate node builder
  private func process(line: MarkdownLine, context: inout CodeConstructContext<Node, Token>) -> Bool
  {
    if line.tokens.count == 1 && line.tokens[0].element == .newline {
      // Handle blank line - close certain types of blocks
      handleBlankLine(&context)
      return true
    }

    let linectx = CodeConstructContext<Node, Token>(
      root: context.root,
      current: context.current,
      tokens: line.tokens,
      state: context.state
    )

    // Try each builder until one handles the line
    for builder in builders {
      var ctx = linectx
      if builder.build(from: &ctx) {
        // Builder handled the line, update context
        context.current = ctx.current
        return true
      }
    }

    // If no builder handled the line, we still consumed it (it's processed as part of block structure)
    return true
  }

  private func handleBlankLine(_ context: inout CodeConstructContext<Node, Token>) {
    // Blank lines close certain types of blocks according to CommonMark spec
    switch context.current {
    case is ParagraphNode:
      // Blank line closes a paragraph
      if let parent = context.current.parent {
        context.current = parent
      }
    case is CodeBlockNode:
      // Blank lines are part of code blocks (indented code blocks)
      // Don't close them here
      break
    case is BlockquoteNode:
      // Blank lines can be part of block quotes (lazy continuation)
      // Don't close immediately
      break
    default:
      // For other block types, move to parent if available
      if let parent = context.current.parent {
        context.current = parent
      }
    }
  }
}
