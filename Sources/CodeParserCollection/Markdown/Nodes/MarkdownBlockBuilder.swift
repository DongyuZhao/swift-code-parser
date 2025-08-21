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
      MarkdownEOFBuilder()  // EOF should be checked first
      // MarkdownATXHeadingBuilder(),
      // MarkdownSetextHeadingBuilder(), // Check before thematic break since - can be both
      // MarkdownThematicBreakBuilder(),
      // MarkdownBlockQuoteBuilder(),
      // MarkdownListBuilder(), // Lists before indented code blocks
      // MarkdownListItemBuilder(), // List item continuation
      // MarkdownFencedCodeBlockBuilder(), // Fenced code blocks before indented
      // MarkdownIndentedCodeBlockBuilder(),
      // MarkdownParagraphBuilder(), // Paragraph should be last as it's the fallback
    ]
  }

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard context.consuming < context.tokens.count else {
      return false
    }

    let lines = lines(from: context)
    guard !lines.isEmpty else { return false }

    for line in lines {
      process(line: line, context: &context)
    }

    // Consume all tokens since we processed all lines
    context.consuming = context.tokens.count

    // Return true to prevent further processing
    return true
  }

  private func process(
    line: [any CodeToken<MarkdownTokenElement>], context: inout CodeConstructContext<Node, Token>
  ) {
    guard let state = context.state as? MarkdownConstructState else {
      return
    }

    // Ensure the state is initialized
    state.position = 0

    repeat {
      state.refreshed = false
      state.refreshed = false

      let tokens = line.suffix(from: state.position)

      for builder in builders {
        var ctx = CodeConstructContext<Node, Token>(
          root: context.root,
          current: context.current,
          tokens: Array(tokens),
          state: context.state
        )

        if builder.build(from: &ctx) {
          // Builder handled the tokens, update context
          context.current = ctx.current

          if state.refreshed {
            // tokens refreshed, stop the builder loop to reprocess the line from new position
            break
          } else {
            // tokens not refreshed, we're done with this line
            return
          }
        }
      }
    } while state.refreshed
  }

  private func lines(from context: CodeConstructContext<Node, Token>) -> [[any CodeToken<MarkdownTokenElement>]] {
    var result: [[any CodeToken<MarkdownTokenElement>]] = []
    var line: [any CodeToken<MarkdownTokenElement>] = []
    var index = context.consuming

    while index < context.tokens.count {
      let token = context.tokens[index]

      if token.element == .eof {
        // Handle EOF: if not after newline, insert newline and treat EOF as blank line
        if !line.isEmpty {
          // Add current line with synthetic newline
          line.append(MarkdownToken(element: .newline, text: token.text, range: token.range))
          result.append(line)
        }
        // Add empty line for EOF
        result.append([])
        break
      } else if token.element == .newline {
        // Include newline token at end of line and preserve empty lines
        line.append(token)
        result.append(line)
        line = []
        index += 1
      } else {
        line.append(token)
        index += 1
      }
    }

    return result
  }
}
