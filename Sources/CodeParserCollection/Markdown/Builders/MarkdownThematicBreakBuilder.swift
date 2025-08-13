import CodeParserCore
import Foundation

/// Builds thematic break nodes (`***`, `---`, `___`).
public final class MarkdownThematicBreakBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  // Exposed for paragraph interruptor checks
  func match(line: String) -> Bool { parse(line) != nil }

  public func build(
    from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    guard context.consuming < context.tokens.count else { return false }
    let (rawLine, consumed) = MarkdownLineReader.nextLine(
      from: context.tokens, startingAt: context.consuming)
    let line = rawLine.trimmingCharacters(in: .newlines)
    guard parse(line) != nil else { return false }
    guard let root = context.current as? MarkdownNodeBase else { return false }
    root.append(ThematicBreakNode())
    context.consuming += consumed
    return true
  }

  /// Returns the marker character if the line is a thematic break.
  private func parse(_ line: String) -> Character? {
    var idx = line.startIndex
    var spaces = 0
    while idx < line.endIndex && line[idx] == " " {
      idx = line.index(after: idx)
      spaces += 1
    }
    if spaces >= 4 { return nil }
    var marker: Character?
    var count = 0
    while idx < line.endIndex {
      let c = line[idx]
      if c == " " || c == "\t" {
        idx = line.index(after: idx)
        continue
      }
      if c == "*" || c == "-" || c == "_" {
        if marker == nil { marker = c } else if marker != c { return nil }
        count += 1
        idx = line.index(after: idx)
      } else {
        return nil
      }
    }
    return count >= 3 ? marker : nil
  }
}
