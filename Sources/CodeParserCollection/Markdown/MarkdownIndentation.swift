import CodeParserCore
import Foundation

/// Utility for computing indentation width treating tabs as aligned to multiples of four columns.
@inline(__always)
func consumeIndentation(
  _ tokens: [any CodeToken<MarkdownTokenElement>],
  start: Int,
  column: Int = 0,
  limit: Int? = nil
) -> (width: Int, index: Int) {
  var idx = start
  var width = 0
  var col = column
  while idx < tokens.count && (limit == nil || width < limit!) {
    let t = tokens[idx]
    let step: Int
    switch t.element {
    case .space:
      step = 1
    case .tab:
      step = 4 - (col % 4)
    default:
      return (width, idx)
    }
    col += step
    width += step
    idx += 1
  }
  return (width, idx)
}
