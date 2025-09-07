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
  package static func detectUnorderedMarker(tokens: [any CodeToken<MarkdownTokenElement>]) -> UnorderedMarker? {
    let (leadingSpaces, _, _) = MarkdownIndentation.calculateIndentation(from: tokens)
    if leadingSpaces > 3 { return nil }
    var i = 0
    while i < tokens.count && tokens[i].element == .whitespaces { i += 1 }
    guard i < tokens.count else { return nil }
    let t = tokens[i]
    guard t.element == .punctuation, ["-", "*", "+"].contains(t.text) else { return nil }
    var next = i + 1
    if next < tokens.count, tokens[next].element == .whitespaces { next += 1 }
    return UnorderedMarker(marker: t.text, nextIndex: next)
  }

  /// Detect ordered list marker at BOL (up to 3 leading spaces). Returns number, delimiter, and index after marker.
  package static func detectOrderedMarker(tokens: [any CodeToken<MarkdownTokenElement>]) -> OrderedMarker? {
    let (leadingSpaces, _, _) = MarkdownIndentation.calculateIndentation(from: tokens)
    if leadingSpaces > 3 { return nil }
    var i = 0
    while i < tokens.count && tokens[i].element == .whitespaces { i += 1 }
    guard i < tokens.count else { return nil }
    let t = tokens[i]
    guard t.element == .characters, t.text.allSatisfy({ $0.isNumber }) else { return nil }
    let j = i + 1
    guard j < tokens.count, tokens[j].element == .punctuation, [".", ")"].contains(tokens[j].text) else { return nil }
    var next = j + 1
    if next < tokens.count, tokens[next].element == .whitespaces { next += 1 }
    return OrderedMarker(numberText: t.text, delimiter: tokens[j].text, nextIndex: next)
  }

  /// Detect either unordered or ordered marker at BOL.
  package static func startsWithAnyMarker(tokens: [any CodeToken<MarkdownTokenElement>]) -> Bool {
    detectUnorderedMarker(tokens: tokens) != nil || detectOrderedMarker(tokens: tokens) != nil
  }
}

