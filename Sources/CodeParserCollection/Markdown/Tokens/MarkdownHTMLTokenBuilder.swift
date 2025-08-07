import CodeParserCore
import Foundation

public class MarkdownHTMLTokenBuilder: CodeTokenBuilder {
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeTokenContext<MarkdownTokenElement>) -> Bool {
    guard context.consuming < context.source.endIndex else { return false }
    let start = context.consuming
    let first = context.source[start]

    if first == "<" {
      // HTML comment <!-- -->
      if context.source[start...].hasPrefix("<!--") {
        if let endRange = context.source.range(
          of: "-->", range: context.source.index(start, offsetBy: 4)..<context.source.endIndex)
        {
          let end = endRange.upperBound
          context.tokens.append(
            MarkdownToken.htmlComment(String(context.source[start..<end]), at: start..<end))
          context.consuming = end
          return true
        }
      }

      // HTML tag/block
      var idx = context.source.index(after: start)
      var isClosing = false
      if idx < context.source.endIndex && context.source[idx] == "/" {
        isClosing = true
        idx = context.source.index(after: idx)
      }
      let nameStart = idx
      while idx < context.source.endIndex
        && (context.source[idx].isLetter || context.source[idx].isNumber
          || context.source[idx] == "-")
      {
        idx = context.source.index(after: idx)
      }
      guard nameStart < idx else { return false }
      let tagName = String(context.source[nameStart..<idx])
      // consume until closing bracket
      var endIdx = idx
      var isSelfClosing = false
      while endIdx < context.source.endIndex {
        let c = context.source[endIdx]
        if c == ">" {
          endIdx = context.source.index(after: endIdx)
          break
        } else if c == "/" {
          let next = context.source.index(after: endIdx)
          if next < context.source.endIndex && context.source[next] == ">" {
            endIdx = context.source.index(after: next)
            isSelfClosing = true
            break
          }
        }
        endIdx = context.source.index(after: endIdx)
      }
      guard endIdx <= context.source.endIndex else { return false }
      let openTagRange = start..<endIdx

      if isClosing || isSelfClosing {
        context.tokens.append(
          MarkdownToken.htmlTag(String(context.source[openTagRange]), at: openTagRange))
        context.consuming = endIdx
        return true
      }

      // look for closing tag
      let remaining = context.source[endIdx...]
      let closingPattern = "</" + tagName + ">"
      if let closeRange = remaining.range(of: closingPattern, options: [.caseInsensitive]) {
        let blockEnd = closeRange.upperBound
        context.tokens.append(
          MarkdownToken.htmlBlock(String(context.source[start..<blockEnd]), at: start..<blockEnd))
        context.consuming = blockEnd
        return true
      }

      context.tokens.append(
        MarkdownToken.htmlUnclosedBlock(String(context.source[openTagRange]), at: openTagRange))
      context.consuming = endIdx
      return true
    } else if first == "&" {
      var idx = context.source.index(after: start)
      if idx < context.source.endIndex && context.source[idx] == "#" {
        idx = context.source.index(after: idx)
        if idx < context.source.endIndex
          && (context.source[idx] == "x" || context.source[idx] == "X")
        {
          idx = context.source.index(after: idx)
          while idx < context.source.endIndex && context.source[idx].isHexDigit {
            idx = context.source.index(after: idx)
          }
        } else {
          while idx < context.source.endIndex && context.source[idx].isNumber {
            idx = context.source.index(after: idx)
          }
        }
        if idx < context.source.endIndex && context.source[idx] == ";" {
          let end = context.source.index(after: idx)
          let range = start..<end
          context.tokens.append(MarkdownToken.htmlEntity(String(context.source[range]), at: range))
          context.consuming = end
          return true
        }
      } else if idx < context.source.endIndex && context.source[idx].isLetter {
        let nameStart = idx
        while idx < context.source.endIndex
          && (context.source[idx].isLetter || context.source[idx].isNumber)
        {
          idx = context.source.index(after: idx)
        }
        if idx < context.source.endIndex && context.source[idx] == ";" {
          let name = String(context.source[nameStart..<idx])
          if Self.validEntities.contains(name) {
            let end = context.source.index(after: idx)
            let range = start..<end
            context.tokens.append(
              MarkdownToken.htmlEntity(String(context.source[range]), at: range))
            context.consuming = end
            return true
          }
        }
      }
    }
    return false
  }

  static let validEntities: Set<String> = [
    "amp", "lt", "gt", "quot", "apos", "nbsp", "copy", "reg", "trade",
    "hellip", "mdash", "ndash", "lsquo", "rsquo", "ldquo", "rdquo",
    "bull", "middot", "times", "divide", "plusmn", "sup2", "sup3",
    "frac14", "frac12", "frac34", "iexcl", "cent", "pound", "curren",
    "yen", "brvbar", "sect", "uml", "ordf", "laquo", "not", "shy",
    "macr", "deg", "plusmn", "acute", "micro", "para", "middot",
    "cedil", "ordm", "raquo", "iquest", "Agrave", "Aacute", "Acirc",
    "Atilde", "Auml", "Aring", "AElig", "Ccedil", "Egrave", "Eacute",
    "Ecirc", "Euml", "Igrave", "Iacute", "Icirc", "Iuml", "ETH",
    "Ntilde", "Ograve", "Oacute", "Ocirc", "Otilde", "Ouml", "times",
    "Oslash", "Ugrave", "Uacute", "Ucirc", "Uuml", "Yacute", "THORN",
    "szlig", "agrave", "aacute", "acirc", "atilde", "auml", "aring",
    "aelig", "ccedil", "egrave", "eacute", "ecirc", "euml", "igrave",
    "iacute", "icirc", "iuml", "eth", "ntilde", "ograve", "oacute",
    "ocirc", "otilde", "ouml", "divide", "oslash", "ugrave", "uacute",
    "ucirc", "uuml", "yacute", "thorn", "yuml",
  ]
}
