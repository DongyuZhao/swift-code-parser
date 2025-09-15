import CodeParserCore
import Foundation

package enum MarkdownListUtils {
  package struct UnorderedMarker {
    let marker: String // "-", "*", "+"
    let nextIndex: Int // token index after marker and optional space
  }

  package struct OrderedMarker {
    let numberText: String // e.g., "1"
    let delimiter: String  // "." or ")"
    let nextIndex: Int     // token index after delimiter and optional space
  }

  /// Detect unordered list marker at BOL (up to 3 leading spaces). Returns marker and index after marker+space.
  package static func detectUnorderedMarker(tokens: [any CodeToken<MarkdownTokenElement>], allowIndented: Bool = false) -> UnorderedMarker? {
    let (leadingSpaces, _, _) = MarkdownIndentation.calculateIndentation(from: tokens)
    if !allowIndented && leadingSpaces > 3 { return nil }
    var i = 0
    while i < tokens.count && tokens[i].element == .whitespaces { i += 1 }
    guard i < tokens.count else { return nil }
    let t = tokens[i]
    guard t.element == .punctuation, ["-", "*", "+"].contains(t.text) else { return nil }
    var next = i + 1
    if next >= tokens.count { return nil }
    let nxt = tokens[next]
    if nxt.element == .whitespaces { next += 1 }
    else if nxt.element != .newline && nxt.element != .eof { return nil }
    // Prevent misidentifying thematic breaks like "- - -" or "* * *" as list markers
    if next < tokens.count, tokens[next].element == .punctuation, tokens[next].text == t.text { return nil }
    return UnorderedMarker(marker: t.text, nextIndex: next)
  }

  /// Detect ordered list marker at BOL (up to 3 leading spaces). Returns number, delimiter, and index after marker.
  package static func detectOrderedMarker(tokens: [any CodeToken<MarkdownTokenElement>], allowIndented: Bool = false) -> OrderedMarker? {
    let (leadingSpaces, _, _) = MarkdownIndentation.calculateIndentation(from: tokens)
    if !allowIndented && leadingSpaces > 3 { return nil }
    var i = 0
    while i < tokens.count && tokens[i].element == .whitespaces { i += 1 }
    guard i < tokens.count else { return nil }
    let t = tokens[i]
    guard t.element == .characters, t.text.allSatisfy({ $0.isNumber }) else { return nil }
    let j = i + 1
    guard j < tokens.count, tokens[j].element == .punctuation, [".", ")"].contains(tokens[j].text) else { return nil }
    var next = j + 1
    if next >= tokens.count { return nil }
    let nxt = tokens[next]
    if nxt.element == .whitespaces { next += 1 }
    else if nxt.element != .newline && nxt.element != .eof { return nil }
    return OrderedMarker(numberText: t.text, delimiter: tokens[j].text, nextIndex: next)
  }

  /// Detect either unordered or ordered marker at BOL.
  package static func startsWithAnyMarker(tokens: [any CodeToken<MarkdownTokenElement>], allowIndented: Bool = false) -> Bool {
    detectUnorderedMarker(tokens: tokens, allowIndented: allowIndented) != nil || detectOrderedMarker(tokens: tokens, allowIndented: allowIndented) != nil
  }
}

