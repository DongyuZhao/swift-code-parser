import CodeParserCore
@testable import CodeParserCollection
import Foundation

// Quick debug script to test inline processing
let input = "*foo bar*"
let markdown = MarkdownMarkupLanguage()
let parser = CodeParser()
let result = parser.parse(input, language: markdown)

print("Input: \(input)")
print("Result: \(sig(result.root))")

// Let's also manually test the inline processor
if let document = result.root as? DocumentNode,
   let paragraph = document.children.first as? ParagraphNode {
    print("Paragraph content: '\(paragraph.content)'")
    print("Paragraph children count: \(paragraph.children.count)")
    
    // Check if tokens are accumulated
    if paragraph.accumulatedTokens.isEmpty {
        print("No accumulated tokens found!")
    } else {
        print("Accumulated tokens:")
        for (i, token) in paragraph.accumulatedTokens.enumerated() {
            print("  \(i): \(token.element) - '\(token.text)'")
        }
        
        // Test inline processor directly
        let inlineProcessor = MarkdownInlineProcessor()
        let inlineNodes = inlineProcessor.processInlineTokens(paragraph.accumulatedTokens)
        print("Inline nodes count: \(inlineNodes.count)")
        for (i, node) in inlineNodes.enumerated() {
            print("  \(i): \(type(of: node)) - \(node)")
            if let textNode = node as? MarkdownText {
                print("    Content: '\(textNode.content)'")
            } else if let emphasisNode = node as? EmphasisNode {
                print("    Emphasis with \(emphasisNode.children.count) children")
            }
        }
    }
}