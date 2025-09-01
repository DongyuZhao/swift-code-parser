import CodeParserCore
import Foundation

/// Main block-level builder that handles line-by-line processing following CommonMark - GFM spec
/// Organizes tokens into logical lines and delegates to specialized CodeNodeBuilder instances
public class MarkdownBlockBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  // Phased block parsing
  private enum BlockPhase: CaseIterable { case openContainer, leafOnLine, postParagraph }

  private struct BlockRule {
    let builder: any CodeNodeBuilder<MarkdownNodeElement, MarkdownTokenElement>
    let phase: BlockPhase
    let priority: Int
  }

  private let rulesByPhase: [BlockPhase: [BlockRule]]

  public init() {
    // Declare rules with explicit phase and priority (lower number runs earlier within phase)
    let rules: [BlockRule] = [
      // Open containers first (strip markers, reprocess line)
      .init(builder: MarkdownBlockQuoteBuilder(), phase: .openContainer, priority: 10),
      .init(builder: MarkdownListBuilder(), phase: .openContainer, priority: 20),
      .init(builder: MarkdownListItemBuilder(), phase: .openContainer, priority: 30),

      // Leaf on line
      .init(builder: MarkdownEOFBuilder(), phase: .leafOnLine, priority: 0),
      .init(builder: MarkdownReferenceLinkDefinitionBuilder(), phase: .leafOnLine, priority: 5),
      .init(builder: MarkdownFencedCodeBlockBuilder(), phase: .leafOnLine, priority: 10),
      .init(builder: MarkdownATXHeadingBuilder(), phase: .leafOnLine, priority: 20),
      .init(builder: MarkdownThematicBreakBuilder(), phase: .leafOnLine, priority: 30),
      .init(builder: MarkdownHTMLBlockBuilder(), phase: .leafOnLine, priority: 35),
      .init(builder: MarkdownIndentedCodeBlockBuilder(), phase: .leafOnLine, priority: 40),
      .init(builder: MarkdownParagraphBuilder(), phase: .leafOnLine, priority: 1000),  // fallback

      // Post paragraph (needs previous paragraph context)
      .init(builder: MarkdownSetextHeadingBuilder(), phase: .postParagraph, priority: 10),
    ]

    var grouped: [BlockPhase: [BlockRule]] = [:]
    for r in rules {
      grouped[r.phase, default: []].append(r)
    }
    // Sort each phase by priority while preserving declaration order as tie-breaker (stable sort)
    self.rulesByPhase = Dictionary(
      uniqueKeysWithValues: grouped.map { phase, arr in
        (
          phase,
          arr.sorted { (a, b) in
            if a.priority == b.priority { return true }  // keep stable
            return a.priority < b.priority
          }
        )
      })
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
    state.isPartialLine = false

    repeat {
      state.refreshed = false

      // Ensure position doesn't exceed line bounds, but allow empty lines for EOF processing
      guard state.position < line.count || (line.isEmpty && state.position == 0) else { break }

      let tokens =
        state.position < line.count
        ? line.suffix(from: state.position) : ArraySlice<any CodeToken<MarkdownTokenElement>>()

      // Run phases in order
      var handledInAnyPhase = false
      for phase in [BlockPhase.openContainer, .leafOnLine, .postParagraph] {
        guard let rules = rulesByPhase[phase] else { continue }

        var handledInPhase = false
        for rule in rules {
          var ctx = CodeConstructContext<Node, Token>(
            root: context.root,
            current: context.current,
            tokens: Array(tokens),
            state: context.state
          )

          if rule.builder.build(from: &ctx) {
            handledInPhase = true
            handledInAnyPhase = true
            // Update context
            context.current = ctx.current

            if state.refreshed {
              // The builder refreshed tokens (container stripped etc.), reprocess from start
              state.isPartialLine = true
              break
            } else {
              // If we're still in openContainer phase, allow proceeding to leafOnLine on same line
              if phase == .openContainer {
                // Continue to next phase without returning; break out of builder loop
                break
              } else {
                // For leaf/post phases, we're done with this line
                return
              }
            }
          }
        }

        if state.refreshed { break }  // restart outer repeat

        // If openContainer phase consumed and didn't refresh, proceed to next phase naturally
        if handledInPhase && phase == .openContainer {
          // fallthrough to next phase
          continue
        }
      }

      // If nothing handled in any phase, break to avoid infinite loop
      if !handledInAnyPhase { break }
    } while state.refreshed
  }

  private func lines(from context: CodeConstructContext<Node, Token>) -> [[any CodeToken<
    MarkdownTokenElement
  >]] {
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
