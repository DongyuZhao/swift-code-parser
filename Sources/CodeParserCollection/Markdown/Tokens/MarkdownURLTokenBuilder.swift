import CodeParserCore
import Foundation

public class MarkdownURLTokenBuilder: CodeTokenBuilder {
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeTokenContext<MarkdownTokenElement>) -> Bool {
    guard context.consuming < context.source.endIndex else { return false }
    let start = context.consuming
    let first = context.source[start]

    // Try autolink <...>
    if first == "<" {
      var index = context.source.index(after: start)
      var content = ""
      while index < context.source.endIndex {
        let char = context.source[index]
        if char == ">" {
          let end = context.source.index(after: index)
          let fullRange = start..<end
          if Self.isValidAutolinkContent(content) {
            let text = String(context.source[fullRange])
            context.consuming = end
            context.tokens.append(MarkdownToken.autolink(text, at: fullRange))
            return true
          }
          return false
        }
        if char == " " || char == "\t" || char == "\n" || char == "\r" || char == "<" {
          return false
        }
        content.append(char)
        index = context.source.index(after: index)
      }
      return false
    }

    if let urlEnd = Self.matchURL(in: context.source, from: start) {
      let text = String(context.source[start..<urlEnd])
      context.consuming = urlEnd
      context.tokens.append(MarkdownToken.url(text, at: start..<urlEnd))
      return true
    }

    if let emailEnd = Self.matchEmail(in: context.source, from: start) {
      let text = String(context.source[start..<emailEnd])
      context.consuming = emailEnd
      context.tokens.append(MarkdownToken.email(text, at: start..<emailEnd))
      return true
    }

    return false
  }

  // MARK: - Simple scanners replacing regex
  private static func isValidAutolinkContent(_ content: String) -> Bool {
    if content.contains("@") {
      return matchEmailContent(content) == content.endIndex
    }
    // scheme ':' rest
    var idx = content.startIndex
    guard idx < content.endIndex, content[idx].isLetter else { return false }
    idx = content.index(after: idx)
    while idx < content.endIndex {
      let c = content[idx]
      if c == ":" { break }
      if !(c.isLetter || c.isNumber || c == "+" || c == "." || c == "-") { return false }
      idx = content.index(after: idx)
    }
    guard idx < content.endIndex, content[idx] == ":" else { return false }
    let afterColon = content.index(after: idx)
    return afterColon < content.endIndex // at least one char after ':'
  }

  private static func matchURL(in source: String, from start: String.Index) -> String.Index? {
    // match http:// or https:// then run until a stopping char
    let rest = source[start...]
    if rest.hasPrefix("http://") || rest.hasPrefix("https://") {
      var idx = source.index(start, offsetBy: rest.hasPrefix("https://") ? 8 : 7)
      while idx < source.endIndex {
        let c = source[idx]
        if c.isWhitespace || c == "<" || c == ">" || c == "[" || c == "]" || c == "(" || c == ")" {
          break
        }
        idx = source.index(after: idx)
      }
      return idx
    }
    return nil
  }

  private static func isEmailLocalChar(_ c: Character) -> Bool {
    return c.isLetter || c.isNumber || c == "." || c == "_" || c == "%" || c == "+" || c == "-"
  }

  private static func isEmailDomainChar(_ c: Character) -> Bool {
    return c.isLetter || c.isNumber || c == "." || c == "-"
  }

  private static func matchEmail(in source: String, from start: String.Index) -> String.Index? {
    var idx = start
    // local part
    var localLen = 0
    while idx < source.endIndex, isEmailLocalChar(source[idx]) {
      localLen += 1
      idx = source.index(after: idx)
    }
    guard localLen > 0, idx < source.endIndex, source[idx] == "@" else { return nil }
    idx = source.index(after: idx)
    // domain
    var seenDot = false
    var lastLabelLen = 0
    while idx < source.endIndex, isEmailDomainChar(source[idx]) {
      if source[idx] == "." { seenDot = true; lastLabelLen = 0 } else { lastLabelLen += 1 }
      idx = source.index(after: idx)
    }
    guard seenDot, lastLabelLen >= 2, idx > start else { return nil }
    return idx
  }

  private static func matchEmailContent(_ content: String) -> String.Index {
    var idx = content.startIndex
    // local
    var localLen = 0
    while idx < content.endIndex, isEmailLocalChar(content[idx]) { localLen += 1; idx = content.index(after: idx) }
    guard localLen > 0, idx < content.endIndex, content[idx] == "@" else { return content.startIndex }
    idx = content.index(after: idx)
    var seenDot = false
    var lastLabelLen = 0
    while idx < content.endIndex, isEmailDomainChar(content[idx]) {
      if content[idx] == "." { seenDot = true; lastLabelLen = 0 } else { lastLabelLen += 1 }
      idx = content.index(after: idx)
    }
    guard seenDot, lastLabelLen >= 2 else { return content.startIndex }
    return idx
  }
}
