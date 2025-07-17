import XCTest
@testable import SwiftParser

enum DummyElement: CodeElement {
    case root
    case identifier
    case number
}

final class SwiftParserTests: XCTestCase {
    func testParserInitialization() {
        let parser = SwiftParser()
        XCTAssertNotNil(parser)
    }

    func testCodeNodeASTOperations() {
        let root = CodeNode(type: DummyElement.root, value: "")
        let a = CodeNode(type: DummyElement.identifier, value: "a")
        let b = CodeNode(type: DummyElement.identifier, value: "b")

        root.addChild(a)
        root.insertChild(b, at: 0)
        XCTAssertEqual(root.children.first?.value, "b")

        let removed = root.removeChild(at: 0)
        XCTAssertEqual(removed.value, "b")
        XCTAssertNil(removed.parent)
        XCTAssertEqual(root.children.count, 1)

        let num = CodeNode(type: DummyElement.number, value: "1")
        root.replaceChild(at: 0, with: num)
        XCTAssertEqual(root.children.first?.value, "1")

        num.removeFromParent()
        XCTAssertEqual(root.children.count, 0)

        let idX = CodeNode(type: DummyElement.identifier, value: "x")
        let num2 = CodeNode(type: DummyElement.number, value: "2")
        root.addChild(idX)
        root.addChild(num2)

        var collected: [CodeNode] = []
        root.traverseDepthFirst { collected.append($0) }
        XCTAssertEqual(collected.count, 3)

        let found = root.first { ($0.type as? DummyElement) == .number }
        XCTAssertEqual(found?.value, "2")

        let allIds = root.findAll { ($0.type as? DummyElement) == .identifier }
        XCTAssertEqual(allIds.count, 1)
        XCTAssertEqual(allIds.first?.value, "x")
        
        XCTAssertEqual(idX.depth, 1)
        XCTAssertEqual(root.subtreeCount, 3)
    }
    
    // MARK: - List Tests
    
    func testMarkdownUnorderedList() {
        let markdown = """
        - item1
        - item2
        - item3
        """
        
        let language = MarkdownLanguage()
        let parser = CodeParser(language: language)
        let result = parser.parse(markdown, rootNode: CodeNode(type: MarkdownElement.document, value: ""))
        
        // Find unordered list
        let listNodes = result.node.findAll { 
            ($0.type as? MarkdownElement) == .unorderedList 
        }
        XCTAssertEqual(listNodes.count, 1)
        
        // Verify list items
        let listItems = listNodes[0].children
        XCTAssertEqual(listItems.count, 3)
        
        // Verify first list item content
        let firstItem = listItems[0]
        XCTAssertEqual(firstItem.children.count, 1)
        XCTAssertEqual(firstItem.children[0].value, "item1")
    }

    func testMarkdownOrderedList() {
        let markdown = """
        1. first
        1. second
        1. third
        """
        
        let language = MarkdownLanguage()
        let parser = CodeParser(language: language)
        let result = parser.parse(markdown, rootNode: CodeNode(type: MarkdownElement.document, value: ""))
        
        // Find ordered list
        let listNodes = result.node.findAll { 
            ($0.type as? MarkdownElement) == .orderedList 
        }
        XCTAssertEqual(listNodes.count, 1)
        
        // Verify list items
        let listItems = listNodes[0].children
        XCTAssertEqual(listItems.count, 3)
        
        // Verify auto numbering
        XCTAssertEqual(listItems[0].value, "1.")
        XCTAssertEqual(listItems[1].value, "2.")
        XCTAssertEqual(listItems[2].value, "3.")
    }

    func testMarkdownTaskList() {
        let markdown = """
        - [ ] unfinished
        - [x] finished
        - [ ] another
        """
        
        let language = MarkdownLanguage()
        let parser = CodeParser(language: language)
        let result = parser.parse(markdown, rootNode: CodeNode(type: MarkdownElement.document, value: ""))
        
        // Find task list
        let taskListNodes = result.node.findAll { 
            ($0.type as? MarkdownElement) == .taskList 
        }
        XCTAssertEqual(taskListNodes.count, 1)
        
        // Verify task list items
        let taskItems = taskListNodes[0].children
        XCTAssertEqual(taskItems.count, 3)
        
        // Verify task state
        XCTAssertEqual(taskItems[0].value, "[ ]")
        XCTAssertEqual(taskItems[1].value, "[x]")
        XCTAssertEqual(taskItems[2].value, "[ ]")
    }
    
    // MARK: - Markdown Tests
    
    func testMarkdownBasicParsing() {
        let parser = SwiftParser()
        let markdown = "# Title\n\nThis is a paragraph."
        let result = parser.parseMarkdown(markdown)
        
        XCTAssertFalse(result.hasErrors, "Parsing should not produce errors")
        XCTAssertEqual(result.root.children.count, 2, "There should be two nodes (header and paragraph)")
        
        // Check header
        let headers = result.markdownNodes(ofType: .header1)
        XCTAssertEqual(headers.count, 1, "There should be one H1 header")
        XCTAssertEqual(headers.first?.value, "Title", "Header text should match")
        
        // Check paragraph
        let paragraphs = result.markdownNodes(ofType: .paragraph)
        XCTAssertEqual(paragraphs.count, 1, "There should be one paragraph")
        XCTAssertEqual(paragraphs.first?.value, "This is a paragraph.", "Paragraph text should match")
    }
    
    func testMarkdownHeaders() {
        let parser = SwiftParser()
        let markdown = """
        # H1
        ## H2
        ### H3
        #### H4
        ##### H5
        ###### H6
        """
        
        let result = parser.parseMarkdown(markdown)
        XCTAssertFalse(result.hasErrors)
        
        XCTAssertEqual(result.markdownNodes(ofType: .header1).count, 1)
        XCTAssertEqual(result.markdownNodes(ofType: .header2).count, 1)
        XCTAssertEqual(result.markdownNodes(ofType: .header3).count, 1)
        XCTAssertEqual(result.markdownNodes(ofType: .header4).count, 1)
        XCTAssertEqual(result.markdownNodes(ofType: .header5).count, 1)
        XCTAssertEqual(result.markdownNodes(ofType: .header6).count, 1)
        
        XCTAssertEqual(result.markdownNodes(ofType: .header1).first?.value, "H1")
        XCTAssertEqual(result.markdownNodes(ofType: .header6).first?.value, "H6")
    }
    
    func testMarkdownEmphasis() {
        let parser = SwiftParser()
        
        // Test the simplest case with debug output
        let simpleMarkdown = "*test*"
        _ = parser.parseMarkdown(simpleMarkdown)
        
        let markdown = "*italic* **bold** ***bold italic***"
        let result = parser.parseMarkdown(markdown)
        
        XCTAssertFalse(result.hasErrors)
        
        let emphasis = result.markdownNodes(ofType: .emphasis)
        let strongEmphasis = result.markdownNodes(ofType: .strongEmphasis)
        
        XCTAssertGreaterThanOrEqual(emphasis.count, 1, "Should have at least one italic")
        XCTAssertGreaterThanOrEqual(strongEmphasis.count, 1, "Should have at least one bold")
    }
    
    func testMarkdownNestedEmphasis() {
        let parser = SwiftParser()
        
        // Start with a simple case
        let simpleTest = "*test*"
        _ = parser.parseMarkdown(simpleTest)
        
        // Test triple markers
        let tripleTest = "***test***"
        
        // Inspect tokenization result
        let tokenizer = MarkdownTokenizer()
        _ = tokenizer.tokenize(tripleTest)
        
        let tripleResult = parser.parseMarkdown(tripleTest)
        
        // Verify triple marker result
        let strongNodes = tripleResult.markdownNodes(ofType: .strongEmphasis)
        _ = strongNodes.count > 0
        
        // Test nested emphasis structures
        let testCases = [
            ("*outer*inner*italic*", "consecutive single asterisks"),
            ("**outer**inner**bold**", "consecutive double asterisks"),
            ("***triple***", "triple markers should become bold italic"),
            ("*italic**bold**italic*", "bold nested in italic"),
            ("**bold*italic*bold**", "italic nested in bold"),
            ("*outer_underline_outer*", "asterisk containing underscore"),
            ("_underline*asterisk*underline_", "underscore containing asterisk")
        ]
        
        for (markdown, description) in testCases {
            let result = parser.parseMarkdown(markdown)
            
            // Basic validation: ensure no errors and content parsed
            XCTAssertFalse(result.hasErrors, "\(description): should parse without errors")
            XCTAssertGreaterThan(result.root.children.count, 0, "\(description): should produce content")
            
            // Special validation for triple markers
            if markdown == "***triple***" {
                let strongEmphasisNodes = result.markdownNodes(ofType: .strongEmphasis)
                    XCTAssertGreaterThan(strongEmphasisNodes.count, 0, "Triple markers should create strongEmphasis")
                
                if let strongNode = strongEmphasisNodes.first {
                    let emphasisNodes = strongNode.children.filter { 
                        ($0.type as? MarkdownElement) == .emphasis 
                    }
                    XCTAssertGreaterThan(emphasisNodes.count, 0, "strongEmphasis should contain nested emphasis")
                }
            }
        }
    }
    
    func testMarkdownInlineCode() {
        let parser = SwiftParser()
        let markdown = "This is `inline code` test"
        let result = parser.parseMarkdown(markdown)
        
        XCTAssertFalse(result.hasErrors)
        
        let inlineCode = result.markdownNodes(ofType: .inlineCode)
        
        XCTAssertEqual(inlineCode.count, 1, "Should find one inline code")
        XCTAssertEqual(inlineCode.first?.value, "inline code", "Inline code content should match")
    }
    
    func testMarkdownCodeBlock() {
        let parser = SwiftParser()
        let markdown = """
        ```swift
        let code = "Hello"
        print(code)
        ```
        """
        
        let result = parser.parseMarkdown(markdown)
        XCTAssertFalse(result.hasErrors)
        
        let codeBlocks = result.markdownNodes(ofType: .fencedCodeBlock)
        XCTAssertEqual(codeBlocks.count, 1, "Should find one code block")
        
        let codeBlock = codeBlocks.first!
        XCTAssertTrue(codeBlock.value.contains("let code"), "Code block should contain code")
        
        // Check language identifier
        if let langNode = codeBlock.children.first {
            XCTAssertEqual(langNode.value, "swift", "Language identifier should be swift")
        }
    }
    
    func testMarkdownLinks() {
        let parser = SwiftParser()
        let markdown = "[Google](https://google.com)"
        let result = parser.parseMarkdown(markdown)
        
        XCTAssertFalse(result.hasErrors)
        
        let links = result.markdownNodes(ofType: .link)
        XCTAssertEqual(links.count, 1, "Should find one link")
        
        let link = links.first!
        XCTAssertEqual(link.value, "Google", "Link text should match")
        
        if let urlNode = link.children.first {
            XCTAssertEqual(urlNode.value, "https://google.com", "Link URL should match")
        }
    }
    
    func testMarkdownImages() {
        let parser = SwiftParser()
        let markdown = "![Alt text](image.jpg)"
        let result = parser.parseMarkdown(markdown)
        
        XCTAssertFalse(result.hasErrors)
        
        let images = result.markdownNodes(ofType: .image)
        XCTAssertEqual(images.count, 1, "Should find one image")
        
        let image = images.first!
        XCTAssertEqual(image.value, "Alt text", "Image alt text should match")
        
        if let urlNode = image.children.first {
            XCTAssertEqual(urlNode.value, "image.jpg", "Image URL should match")
        }
    }
    
    func testMarkdownBlockquote() {
        let parser = SwiftParser()
        let markdown = "> A quote\n> Multiple lines"
        let result = parser.parseMarkdown(markdown)
        
        XCTAssertFalse(result.hasErrors)
        
        let blockquotes = result.markdownNodes(ofType: .blockquote)
        XCTAssertEqual(blockquotes.count, 1, "Should find one blockquote")
        
        let blockquote = blockquotes.first!
        XCTAssertTrue(blockquote.value.contains("A quote"), "Blockquote should contain text")
    }
    
    func testSpecificNesting() {
        let parser = SwiftParser()
        let testCase = "**bold*italic*bold**"
        
        // Check tokenization result
        let tokenizer = MarkdownTokenizer()
        _ = tokenizer.tokenize(testCase)
        
        let result = parser.parseMarkdown(testCase)
        
        let strongEmphasis = result.markdownNodes(ofType: .strongEmphasis)
        
        // Should have one strongEmphasis node with correct content
        XCTAssertEqual(strongEmphasis.count, 1, "Should have one strongEmphasis node")
    }
    
    // MARK: - Footnote and Citation Tests
    
    func testMarkdownFootnotes() {
        let language = MarkdownLanguage()
        
        // Test footnote definition
        let footnoteDefinition = "[^1]: This is a footnote."
        let result1 = language.parse(footnoteDefinition)
        
        let footnoteNodes = result1.node.findAll { node in
            if let element = node.type as? MarkdownElement {
                return element == .footnoteDefinition
            }
            return false
        }
        
        XCTAssertEqual(footnoteNodes.count, 1, "Should have one footnote definition")
        XCTAssertEqual(footnoteNodes.first?.value, "1", "Footnote identifier should be '1'")
        
        // Test footnote reference
        let footnoteReference = "This is text with a footnote[^1]."
        let result2 = language.parse(footnoteReference)
        
        let footnoteRefNodes = result2.node.findAll { node in
            if let element = node.type as? MarkdownElement {
                return element == .footnoteReference
            }
            return false
        }
        
        XCTAssertEqual(footnoteRefNodes.count, 1, "Should have one footnote reference")
        XCTAssertEqual(footnoteRefNodes.first?.value, "1", "Footnote reference should be '1'")
        
        // Test complete footnote document
        let completeFootnote = """
        This is a paragraph with a footnote[^1] and another[^note].
        
        [^1]: This is the first footnote.
        [^note]: This is the second footnote.
        """
        
        let result3 = language.parse(completeFootnote)
        
        let allFootnoteRefs = result3.node.findAll { node in
            if let element = node.type as? MarkdownElement {
                return element == .footnoteReference
            }
            return false
        }
        
        let allFootnoteDefs = result3.node.findAll { node in
            if let element = node.type as? MarkdownElement {
                return element == .footnoteDefinition
            }
            return false
        }
        
        XCTAssertEqual(allFootnoteRefs.count, 2, "Should have two footnote references")
        XCTAssertEqual(allFootnoteDefs.count, 2, "Should have two footnote definitions")
    }
    
    func testMarkdownCitations() {
        let language = MarkdownLanguage()
        
        // Test citation definition
        let citationDefinition = "[@smith2023]: Smith, J. (2023). Example Paper."
        let result1 = language.parse(citationDefinition)
        
        let citationNodes = result1.node.findAll { node in
            if let element = node.type as? MarkdownElement {
                return element == .citation
            }
            return false
        }
        
        XCTAssertEqual(citationNodes.count, 1, "Should have one citation definition")
        XCTAssertEqual(citationNodes.first?.value, "smith2023", "Citation identifier should be 'smith2023'")
        
        // Test citation reference
        let citationReference = "According to recent research[@smith2023]."
        let result2 = language.parse(citationReference)
        
        let citationRefNodes = result2.node.findAll { node in
            if let element = node.type as? MarkdownElement {
                return element == .citationReference
            }
            return false
        }
        
        XCTAssertEqual(citationRefNodes.count, 1, "Should have one citation reference")
        XCTAssertEqual(citationRefNodes.first?.value, "smith2023", "Citation reference should be 'smith2023'")
        
        // Test complete citation document
        let completeCitation = """
        This research follows established practices[@smith2023] and [@jones2022].
        
        [@smith2023]: Smith, J. (2023). Example Paper. Journal of Examples.
        [@jones2022]: Jones, A. (2022). Another Paper. Research Quarterly.
        """
        
        let result3 = language.parse(completeCitation)
        
        let allCitationRefs = result3.node.findAll { node in
            if let element = node.type as? MarkdownElement {
                return element == .citationReference
            }
            return false
        }
        
        let allCitationDefs = result3.node.findAll { node in
            if let element = node.type as? MarkdownElement {
                return element == .citation
            }
            return false
        }
        
        XCTAssertEqual(allCitationRefs.count, 2, "Should have two citation references")
        XCTAssertEqual(allCitationDefs.count, 2, "Should have two citation definitions")
    }
    
    func testFootnoteDebug() {
        let tokenizer = MarkdownTokenizer()
        let language = MarkdownLanguage()
        
        // Test footnote reference
        let footnoteRefText = "Text[^1]more"
        _ = tokenizer.tokenize(footnoteRefText)
        _ = language.parse(footnoteRefText)
        
        // Manually test the footnote reference consumer
        let consumer = MarkdownFootnoteReferenceConsumer()
        let testTokens = tokenizer.tokenize("[^1]")
        let testNode = CodeNode(type: MarkdownElement.document, value: "")
        var testContext = CodeContext(tokens: testTokens, currentNode: testNode, errors: [])
        
        _ = consumer.consume(context: &testContext, token: testTokens[0])
    }
}
