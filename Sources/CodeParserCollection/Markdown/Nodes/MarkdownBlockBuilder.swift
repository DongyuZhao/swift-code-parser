import CodeParserCore
import Foundation

/// Main block-level builder that handles line-by-line processing following CommonMark - GFM spec
/// Organizes tokens into logical lines and delegates to specialized CodeNodeBuilder instances
public class MarkdownBlockBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  // Phased block parsing
  public enum Phase: CaseIterable {
    case creation
    case continuation
    case construction
    case finalization

    /// Indicates if the phase allows yielding remaining tokens for re-processing
    var refreshable: Bool {
      switch self {
      case .creation, .continuation:
        return true
      case .construction, .finalization:
        return false
      }
    }
  }

  private let resolvers: [Phase: [any MarkdownBlockResolver]]

  public init() {
    self.resolvers = [
      .creation: [
        MarkdownBlockquoteCreationResolver(),
        MarkdownUnorderedListCreationResolver(),
        MarkdownOrderedListCreationResolver(),
        MarkdownSetextHeadingCreationResolver(),
        MarkdownThematicBreakCreationResolver(),
        MarkdownFencedCodeBlockCreationResolver(),
        MarkdownIndentedCodeBlockCreationResolver(),
        MarkdownReferenceDefinitionResolver(),
        MarkdownHTMLBlockCreationResolver(),
        MarkdownATXHeadingCreationResolver(),
        MarkdownParagraphCreationResolver(),
      ],
      .continuation: [
        MarkdownBlockquoteContinuationResolver(),
        MarkdownUnorderedListContinuationResolver(),
        MarkdownOrderedListContinuationResolver(),
        MarkdownThematicBreakContinuationResolver(),
        MarkdownFencedCodeBlockContinuationResolver(),
        MarkdownIndentedCodeBlockContinuationResolver(),
        MarkdownATXHeadingContinuationResolver(),
        MarkdownParagraphContinuationResolver(),
        MarkdownSetextHeadingContinuationResolver(),
      ],
      .construction: [
        MarkdownBlockquoteConstructionResolver(),
        MarkdownUnorderedListConstructionResolver(),
        MarkdownOrderedListConstructionResolver(),
        MarkdownThematicBreakConstructionResolver(),
        MarkdownFencedCodeBlockConstructionResolver(),
        MarkdownIndentedCodeBlockConstructionResolver(),
        MarkdownATXHeadingConstructionResolver(),
        MarkdownParagraphConstructionResolver(),
        MarkdownSetextHeadingConstructionResolver(),
      ],
      .finalization: [
        MarkdownInlineFinalizeResolver(),
      ],
    ]
  }

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    guard context.consuming < context.tokens.count else {
      return false
    }

    let lines = lines(from: context)

    guard !lines.isEmpty else {
      return false
    }

    var ctx = MarkdownBlockContext(current: context.current)

    for line in lines {
      process(line: line, context: &ctx)
    }

    // Consume all tokens since we processed all lines
    context.consuming = context.tokens.count

    // Run finalization phase for EOF processing
    finalize(context: &ctx)

    // Return true to prevent further processing
    return true
  }

  private func process(line: [any CodeToken<MarkdownTokenElement>], context: inout MarkdownBlockContext) {
    // Process each phase in order
    var ctx = MarkdownBlockContext(
      current: context.current,
      tokens: line
    )
    
    for phase in [Phase.continuation, .creation, .construction] {
      guard let phaseResolvers = resolvers[phase] else { continue }
      var refreshIterations = 0
      repeat {
        refreshIterations += 1
        ctx.refreshed = false
        for resolver in phaseResolvers {
          if resolver.resolve(from: &ctx) {
            break // Stop after first resolver that handled the line
          }
        }
        // Safety guard to avoid accidental infinite refresh cycles
      } while phase.refreshable && ctx.refreshed && refreshIterations < 64
    }
    context.current = ctx.current
  }

  private func finalize(context: inout MarkdownBlockContext) {
    guard let finalizers = resolvers[.finalization] else { return }

    for resolver in finalizers {
      _ = resolver.resolve(from: &context)
    }
  }

  private func lines(from context: CodeConstructContext<Node, Token>) -> [[any CodeToken<MarkdownTokenElement>]] {
    var result: [[any CodeToken<MarkdownTokenElement>]] = []
    var line: [any CodeToken<MarkdownTokenElement>] = []
    var index = context.consuming

    while index < context.tokens.count {
      let token = context.tokens[index]

      if token.element == .eof {
        // EOF should always be its own line
        if !line.isEmpty {
          // Add current line with synthetic newline
          line.append(MarkdownToken(element: .newline, text: "\n", range: token.range))
          result.append(line)
        }
        result.append([token])
      } else {
        line.append(token)
        if token.element == .newline {
          // End of line
          result.append(line)
          line = []
        }
      }
      index += 1
    }
    return result
  }
}
