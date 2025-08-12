import Foundation

/// Shared helpers for CommonMark-style backslash escaping.
enum MarkdownEscaping {
  /// CommonMark escapable ASCII punctuation characters.
  static let escapable: Set<Character> = Set("!\"#$%&'()*+,-./:;<=>?@[]\\^_`{|}~")

  /// Whether the character at `index` is escaped by a preceding odd-length run of backslashes.
  static func isEscapedByBackslash(in source: String, at index: String.Index) -> Bool {
    guard index > source.startIndex else { return false }
    var i = source.index(before: index)
    var count = 0
    while true {
      if source[i] == "\\" { count += 1 } else { break }
      if i == source.startIndex { break }
      i = source.index(before: i)
    }
    return count % 2 == 1
  }

  /// Unescape backslashes for escapable ASCII punctuation; leave other sequences intact.
  static func unescapeBackslashes(_ s: String) -> String {
    if s.isEmpty { return s }
    var out = String()
    out.reserveCapacity(s.count)
    var iter = s.makeIterator()
    var prevSlash = false
    while let ch = iter.next() {
      if prevSlash {
        if escapable.contains(ch) {
          out.append(ch)
        } else {
          out.append("\\")
          out.append(ch)
        }
        prevSlash = false
      } else {
        if ch == "\\" { prevSlash = true } else { out.append(ch) }
      }
    }
    if prevSlash { out.append("\\") }
    return out
  }
}
