import CodeParserCore
import Foundation

/// Orchestrates block-level Markdown builders to construct a document tree.
public class MarkdownDocumentBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(
    from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    // Run only at the start of parsing and consume all tokens in one pass.
    guard context.consuming == 0 else { return false }
    guard let root = context.current as? MarkdownNodeBase else { return false }

    let source = context.tokens.map { $0.text }.joined()
    let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

    let headingBuilder = MarkdownATXHeadingBuilder()
    let thematicBuilder = MarkdownThematicBreakBuilder()
    let codeBuilder = MarkdownIndentedCodeBlockBuilder()
    let paragraphBuilder = MarkdownParagraphBuilder(
      interruptors: [
        { headingBuilder.match(line: $0) },
        { thematicBuilder.match(line: $0) },
      ]
    )
    let builders: [MarkdownBlockBuilder] = [
      headingBuilder,
      thematicBuilder,
      codeBuilder,
      paragraphBuilder,
    ]

    var index = 0
    while index < lines.count {
      let line = lines[index]
      if line.trimmingCharacters(in: .whitespaces).isEmpty {
        index += 1
        continue
      }
      for builder in builders {
        if builder.match(line: line) {
          builder.build(lines: lines, index: &index, root: root)
          break
        }
      }
    }

    context.consuming = context.tokens.count
    return true
  }
}
