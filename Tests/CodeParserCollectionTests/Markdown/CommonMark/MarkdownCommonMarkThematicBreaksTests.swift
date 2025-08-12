import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Thematic Breaks (Strict)")
struct MarkdownCommonMarkThematicBreaksTests {
  private let h = MarkdownTestHarness()

  @Test("Valid thematic break '---'")
  func validDash3() { let r = h.parser.parse("---", language: h.language); #expect(r.errors.isEmpty); #expect(r.root.children.count == 1); #expect(r.root.children.first is ThematicBreakNode) }

  @Test("Valid thematic break '***'")
  func validStar3() { let r = h.parser.parse("***", language: h.language); #expect(r.errors.isEmpty); #expect(r.root.children.count == 1); #expect(r.root.children.first is ThematicBreakNode) }

  @Test("Valid thematic break '___'")
  func validUnderscore3() { let r = h.parser.parse("___", language: h.language); #expect(r.errors.isEmpty); #expect(r.root.children.count == 1); #expect(r.root.children.first is ThematicBreakNode) }

  @Test("Valid thematic break '- - -'")
  func validDashSpaced() { let r = h.parser.parse("- - -", language: h.language); #expect(r.errors.isEmpty); #expect(r.root.children.count == 1); #expect(r.root.children.first is ThematicBreakNode) }

  @Test("Valid thematic break '* * *'")
  func validStarSpaced() { let r = h.parser.parse("* * *", language: h.language); #expect(r.errors.isEmpty); #expect(r.root.children.count == 1); #expect(r.root.children.first is ThematicBreakNode) }

  @Test("Valid thematic break '_ _ _'")
  func validUnderscoreSpaced() { let r = h.parser.parse("_ _ _", language: h.language); #expect(r.errors.isEmpty); #expect(r.root.children.count == 1); #expect(r.root.children.first is ThematicBreakNode) }

  @Test("Valid thematic break long '----------'")
  func validDashLong() { let r = h.parser.parse(String(repeating: "-", count: 10), language: h.language); #expect(r.errors.isEmpty); #expect(r.root.children.count == 1); #expect(r.root.children.first is ThematicBreakNode) }

  @Test("Valid thematic break with spaces '   ---   '")
  func validDashWithSpaces() { let r = h.parser.parse("   ---   ", language: h.language); #expect(r.errors.isEmpty); #expect(r.root.children.count == 1); #expect(r.root.children.first is ThematicBreakNode) }

  @Test("Invalid thematic break '--'")
  func invalidDash2() { let r = h.parser.parse("--", language: h.language); #expect(r.errors.isEmpty); let has = r.root.children.contains { $0 is ThematicBreakNode }; #expect(!has) }

  @Test("Invalid thematic break '- -'")
  func invalidDash1Spaced() { let r = h.parser.parse("- -", language: h.language); #expect(r.errors.isEmpty); let has = r.root.children.contains { $0 is ThematicBreakNode }; #expect(!has) }

  @Test("Invalid thematic break '----a'")
  func invalidTextAfter() { let r = h.parser.parse("----a", language: h.language); #expect(r.errors.isEmpty); let has = r.root.children.contains { $0 is ThematicBreakNode }; #expect(!has) }
}
