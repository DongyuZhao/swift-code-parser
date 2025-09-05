import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Test("Debug thematic break interruption")
func debugThematicBreakInterruption() {
  let language = MarkdownLanguage()
  let parser = CodeParser(language: language)
  
  let input = "Foo\n***\nbar"
  print("\n=== DEBUGGING: \(input.debugDescription) ===")
  
  let result = parser.parse(input, language: language)
  
  print("Tokens (\(result.tokens.count)):")
  for (i, token) in result.tokens.enumerated() {
    print("  \(i): \(token.element) = \(token.text.debugDescription)")
  }
  
  print("Final AST:")
  print("  Actual:   \(sig(result.root))")
  print("  Expected: document[paragraph[text(\"Foo\")],thematic_break,paragraph[text(\"bar\")]]")
  
  print("Errors (\(result.errors.count)):")
  for error in result.errors {
    print("  - \(error.message)")
  }
  
  print("=== END DEBUG ===\n")
}