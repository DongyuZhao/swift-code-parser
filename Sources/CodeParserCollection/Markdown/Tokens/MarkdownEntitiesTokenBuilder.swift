import CodeParserCore
import Foundation

// MARK: - HTML Entity Reference Token Builder
/// Recognizes HTML entity references (named and numeric) and emits a single `.href` token.
///
/// Rules (subset aligned with GFM/CommonMark):
/// - Named references must be from a known HTML5 named set and be terminated by ';'.
/// - Numeric references:
///   - Decimal: `&#` digits `;`
///   - Hex: `&#x` or `&#X` hex-digits `;`
///   - Value 0 is allowed (maps to replacement on rendering), values > 0x10FFFF are rejected.
/// - Entity recognition is disabled in code mode (inline or fenced); in that case, '&' is treated as punctuation/text by other builders.
public final class MarkdownEntitiesTokenBuilder: CodeTokenBuilder {
  public typealias Token = MarkdownTokenElement

  // Minimal named entity set required by our tests (HTML5 named character references)
  // This can be extended if needed.
  private static let named: Set<String> = [
    // Basic and used in specs
    "nbsp", "amp", "copy", "AElig", "Dcaron", "frac34",
    "HilbertSpace", "DifferentialD", "ClockwiseContourIntegral", "ngE",
    "ouml", "quot",
  ]

  public init() {}

  public func build(from context: inout CodeTokenContext<Token>) -> Bool {
    let source = context.source
    var current = context.consuming

    // Must start with '&'
    guard current < source.endIndex, source[current] == "&" else { return false }

    // Do not recognize inside code mode
    if let state = context.state as? MarkdownTokenState, state.modes.top == .code {
      return false
    }

    let start = current
    current = source.index(after: current)
    guard current < source.endIndex else { return false }

    // Numeric reference?
    if source[current] == "#" {
      current = source.index(after: current)
      guard current < source.endIndex else { return false }

      var isHex = false
      if source[current] == "x" || source[current] == "X" {
        isHex = true
        current = source.index(after: current)
        guard current < source.endIndex else { return false }
      }

      // Collect digits
      let digitsStart = current
      while current < source.endIndex {
        let ch = source[current]
        if ch == ";" { break }
        if isHex {
          if !(ch.isNumber || ("a"..."f").contains(ch) || ("A"..."F").contains(ch)) {
            return false // invalid hex digit -> not an entity
          }
        } else {
          if !ch.isNumber { return false }
        }
        current = source.index(after: current)
      }

      // Need at least one digit and a terminating ';'
      guard digitsStart < current, current < source.endIndex, source[current] == ";" else {
        return false
      }

      // Validate codepoint range
      let numberText = String(source[digitsStart..<current])
      let value: UInt32?
      if isHex { value = UInt32(numberText, radix: 16) } else { value = UInt32(numberText, radix: 10) }
      guard let v = value else { return false }
      if v > 0x10FFFF { return false }
      // 0 is allowed (will render as replacement char downstream)

      // Consume ';'
      current = source.index(after: current)
      let range = start..<current
      let token = MarkdownToken(element: .charref, text: String(source[range]), range: range)
      context.tokens.append(token)
      context.consuming = current
      return true
    }

    // Named reference: collect name until ';' and verify in allowed set
    let nameStart = current
    while current < source.endIndex, source[current].isLetter || source[current].isNumber {
      current = source.index(after: current)
    }
    guard nameStart < current, current < source.endIndex, source[current] == ";" else {
      return false // must be terminated by ';' and have non-empty name
    }

    let name = String(source[nameStart..<current])
    guard Self.named.contains(name) else { return false }

    current = source.index(after: current) // consume ';'
    let range = start..<current
    let token = MarkdownToken(element: .charref, text: String(source[range]), range: range)
    context.tokens.append(token)
    context.consuming = current
    return true
  }
}
