import XCTest
@testable import SwiftParser

final class SwiftParserTests: XCTestCase {

    func testParserInitialization() {
        let parser = SwiftParser()
        XCTAssertNotNil(parser)
    }

    func testPythonAssignment() {
        let parser = SwiftParser()
        let source = "x = 1"
        let result = parser.parse(source, language: PythonLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.first?.type as? PythonLanguage.Element, PythonLanguage.Element.assignment)
    }

    func testMarkdownHeading() {
        let parser = SwiftParser()
        let source = "# Title\nHello"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.count, 2)
        let heading = result.root.children.first as? MarkdownHeadingNode
        XCTAssertEqual(heading?.level, 1)
    }

    func testMarkdownComplexATXHeading() {
        let parser = SwiftParser()
        let source = "### Complex ###\n"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.count, 1)
        let heading = result.root.children.first as? MarkdownHeadingNode
        XCTAssertEqual(heading?.type as? MarkdownLanguage.Element, .heading)
        XCTAssertEqual(heading?.value, "Complex")
        XCTAssertEqual(heading?.level, 3)
    }

    func testMarkdownSetextHeading() {
        let parser = SwiftParser()
        let source = "Title\n----\n"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        let heading = result.root.children.first as? MarkdownHeadingNode
        XCTAssertEqual(heading?.type as? MarkdownLanguage.Element, .heading)
        XCTAssertEqual(heading?.level, 2)
    }

    func testMarkdownListItem() {
        let parser = SwiftParser()
        let source = "- item1\n- item2"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.count, 1)
        let list = result.root.children.first
        XCTAssertEqual(list?.type as? MarkdownLanguage.Element, .unorderedList)
        XCTAssertEqual(list?.children.count, 2)
        XCTAssertEqual(list?.children.first?.type as? MarkdownLanguage.Element, .listItem)
        XCTAssertEqual((list as? MarkdownUnorderedListNode)?.level, 1)
    }

    func testMarkdownOrderedList() {
        let parser = SwiftParser()
        let source = "1. first\n2. second"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        let list = result.root.children.first
        XCTAssertEqual(list?.type as? MarkdownLanguage.Element, .orderedList)
        XCTAssertEqual(list?.children.count, 2)
        XCTAssertEqual(list?.children.first?.type as? MarkdownLanguage.Element, .orderedListItem)
        XCTAssertEqual((list as? MarkdownOrderedListNode)?.level, 1)
    }

    func testMarkdownNestedList() {
        let parser = SwiftParser()
        let source = "- item1\n  - sub\n- item2"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        let list = result.root.children.first
        XCTAssertEqual(list?.type as? MarkdownLanguage.Element, .unorderedList)
        XCTAssertEqual(list?.children.count, 2)
        let sub = list?.children.first?.children.first
        XCTAssertEqual(sub?.type as? MarkdownLanguage.Element, .unorderedList)
        XCTAssertEqual((list as? MarkdownUnorderedListNode)?.level, 1)
        XCTAssertEqual((sub as? MarkdownUnorderedListNode)?.level, 2)
    }

    func testMarkdownLooseList() {
        let parser = SwiftParser()
        let source = "- a\n\n- b"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.first?.value, "loose")
    }

    func testMarkdownEmphasisAndStrong() {
        let parser = SwiftParser()
        let source = "*em* **strong**"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.count, 1)
        let para = result.root.children.first
        XCTAssertEqual(para?.type as? MarkdownLanguage.Element, .paragraph)
        XCTAssertEqual(para?.children.first?.type as? MarkdownLanguage.Element, .emphasis)
        XCTAssertEqual(para?.children.last?.type as? MarkdownLanguage.Element, .strong)
    }

    func testMarkdownNestedEmphasis() {
        let parser = SwiftParser()
        let source = "*a **b** c*"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.count, 1)
        let para = result.root.children.first
        XCTAssertEqual(para?.type as? MarkdownLanguage.Element, .paragraph)
        let em = para?.children.first
        XCTAssertEqual(em?.type as? MarkdownLanguage.Element, .emphasis)
        XCTAssertEqual(em?.children.count, 3)
        XCTAssertEqual(em?.children[1].type as? MarkdownLanguage.Element, .strong)
    }

    func testMarkdownCodeBlockAndInline() {
        let parser = SwiftParser()
        let source = "```\ncode\n```\ninline `code`"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        let block = result.root.children.first as? MarkdownCodeBlockNode
        XCTAssertEqual(block?.type as? MarkdownLanguage.Element, .codeBlock)
        XCTAssertNil(block?.lang)
        XCTAssertEqual(block?.content, "code\n")
        let para = result.root.children.last
        XCTAssertEqual(para?.type as? MarkdownLanguage.Element, .paragraph)
        XCTAssertEqual(para?.children.last?.type as? MarkdownLanguage.Element, .inlineCode)
    }

    func testMarkdownFencedCodeBlockWithInfo() {
        let parser = SwiftParser()
        let source = "```swift\nprint(\"hi\")\n```"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.count, 1)
        let block = result.root.children.first as? MarkdownCodeBlockNode
        XCTAssertEqual(block?.type as? MarkdownLanguage.Element, .codeBlock)
        XCTAssertEqual(block?.lang, "swift")
        XCTAssertEqual(block?.content, "print(\"hi\")\n")
    }

    func testMarkdownTildeCodeBlock() {
        let parser = SwiftParser()
        let source = "~~~\nprint(\"hi\")\n~~~"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.count, 1)
        let block = result.root.children.first as? MarkdownCodeBlockNode
        XCTAssertEqual(block?.type as? MarkdownLanguage.Element, .codeBlock)
        XCTAssertNil(block?.lang)
        XCTAssertEqual(block?.content, "print(\"hi\")\n")
    }

    func testMarkdownMultiLineFencedCodeBlock() {
        let parser = SwiftParser()
        let source = "```swift\nprint(\"hi\")\nprint(\"bye\")\n```"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.count, 1)
        let block = result.root.children.first as? MarkdownCodeBlockNode
        XCTAssertEqual(block?.lang, "swift")
        XCTAssertEqual(block?.content, "print(\"hi\")\nprint(\"bye\")\n")
    }

    func testMarkdownLink() {
        let parser = SwiftParser()
        let source = "[title](url)"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.first?.type as? MarkdownLanguage.Element, .link)
        let link = result.root.children.first as? MarkdownLinkNode
        XCTAssertEqual(link?.url, "url")
        XCTAssertEqual((link?.text.first as? MarkdownTextNode)?.value, "title")
    }

    func testMarkdownAutoLinkWithoutBrackets() {
        let parser = SwiftParser()
        let source = "https://example.com"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.first?.type as? MarkdownLanguage.Element, .autoLink)
        let auto = result.root.children.first as? MarkdownAutoLinkNode
        XCTAssertEqual(auto?.url, "https://example.com")
    }

    func testMarkdownReferenceLink() {
        let parser = SwiftParser()
        let source = "[title][ref]\n[ref]: http://example.com"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.first?.type as? MarkdownLanguage.Element, .link)
    }

    func testMarkdownBlockQuote() {
        let parser = SwiftParser()
        let source = "> quote"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.first?.type as? MarkdownLanguage.Element, .blockQuote)
    }

    func testMarkdownImage() {
        let parser = SwiftParser()
        let source = "![alt](url)"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.first?.type as? MarkdownLanguage.Element, .image)
        let image = result.root.children.first as? MarkdownImageNode
        XCTAssertEqual(image?.alt, "alt")
        XCTAssertEqual(image?.url, "url")
    }

    func testMarkdownEscapedCharacters() {
        let parser = SwiftParser()
        let source = "\\*not italic\\*"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.count, 1)
        XCTAssertEqual(result.root.children.first?.value, "*not italic*")
    }

    func testMarkdownHardBreakWithSpaces() {
        let parser = SwiftParser()
        let source = "line1  \nline2"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.count, 1)
        XCTAssertEqual(result.root.children.first?.type as? MarkdownLanguage.Element, .paragraph)
        XCTAssertEqual(result.root.children.first?.value, "line1\nline2")
    }

    func testMarkdownHardBreakWithBackslash() {
        let parser = SwiftParser()
        let source = "line1\\\nline2"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.count, 1)
        XCTAssertEqual(result.root.children.first?.type as? MarkdownLanguage.Element, .paragraph)
        XCTAssertEqual(result.root.children.first?.value, "line1\nline2")
    }

    func testMarkdownEntityDecoding() {
        let parser = SwiftParser()
        let source = "&amp;&#35;&#x41;"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.count, 3)
        XCTAssertEqual(result.root.children[0].value, "&")
        XCTAssertEqual(result.root.children[1].value, "#")
        XCTAssertEqual(result.root.children[2].value, "A")
    }

    func testPrattExpression() {
        let parser = SwiftParser()
        let source = "x = 1 + 2 * 3"
        let result = parser.parse(source, language: PythonLanguage())
        XCTAssertEqual(result.errors.count, 0)
        let assign = result.root.children.first
        XCTAssertEqual(assign?.children.first?.type as? PythonLanguage.Element, PythonLanguage.Element.expression)
    }

    func testStableNodeID() {
        let n1 = CodeNode(type: PythonLanguage.Element.identifier, value: "x")
        n1.addChild(CodeNode(type: PythonLanguage.Element.number, value: "1"))

        let n2 = CodeNode(type: PythonLanguage.Element.identifier, value: "x")
        n2.addChild(CodeNode(type: PythonLanguage.Element.number, value: "1"))

        XCTAssertEqual(n1.id, n2.id)
    }

    func testUnterminatedStringError() {
        let parser = SwiftParser()
        let source = "x = \"hello"
        let result = parser.parse(source, language: PythonLanguage())
        XCTAssertEqual(result.errors.count, 1)
    }

    func testContextSnapshotRestore() {
        let tokenizer = PythonLanguage.Tokenizer()
        let tokens = tokenizer.tokenize("x = 1")
        let root = CodeNode(type: PythonLanguage.Element.root, value: "")
        var ctx = CodeContext(tokens: tokens, index: 0, currentNode: root, errors: [], input: "x = 1")
        let snap = ctx.snapshot()
        ctx.index = 2
        ctx.errors.append(CodeError("err"))
        ctx.currentNode.addChild(CodeNode(type: PythonLanguage.Element.number, value: "1"))
        ctx.restore(snap)
        XCTAssertEqual(ctx.index, 0)
        XCTAssertEqual(ctx.errors.count, 0)
        XCTAssertEqual(root.children.count, 0)
    }

    func testIncrementalUpdateRollback() {
        let lang = PythonLanguage()
        let parser = CodeParser(tokenizer: lang.tokenizer, builders: lang.builders, expressionBuilders: lang.expressionBuilders)
        let root = CodeNode(type: lang.rootElement, value: "")
        _ = parser.parse("x = 1", rootNode: root)
        XCTAssertEqual(root.children.first?.children.first?.value, "1")
        _ = parser.update("x = 2", rootNode: root)
        XCTAssertEqual(root.children.first?.children.first?.value, "2")
    }

    func testUnregisterElementBuilder() {
        let tokenizer = PythonLanguage.Tokenizer()
        let expr = PythonLanguage.ExpressionBuilder()
        let assign = PythonLanguage.AssignmentBuilder(expressionBuilder: expr)
        let parser = CodeParser(tokenizer: tokenizer)
        parser.register(builder: assign)
        parser.register(expressionBuilder: expr)

        let root1 = CodeNode(type: PythonLanguage.Element.root, value: "")
        _ = parser.parse("x = 1", rootNode: root1)
        XCTAssertEqual(root1.children.first?.type as? PythonLanguage.Element, .assignment)

        parser.unregister(builder: assign)

        let root2 = CodeNode(type: PythonLanguage.Element.root, value: "")
        _ = parser.parse("x = 1", rootNode: root2)
        XCTAssertEqual(root2.children.first?.type as? PythonLanguage.Element, .identifier)
    }

    func testUnregisterExpressionBuilder() {
        let tokenizer = PythonLanguage.Tokenizer()
        let expr = PythonLanguage.ExpressionBuilder()
        let parser = CodeParser(tokenizer: tokenizer)
        parser.register(expressionBuilder: expr)

        let root1 = CodeNode(type: PythonLanguage.Element.root, value: "")
        _ = parser.parse("1 + 2", rootNode: root1)
        XCTAssertEqual(root1.children.count, 1)

        parser.unregister(expressionBuilder: expr)

        let root2 = CodeNode(type: PythonLanguage.Element.root, value: "")
        _ = parser.parse("1 + 2", rootNode: root2)
        XCTAssertEqual(root2.children.count, 0)
    }

    // MARK: - Additional CommonMark Tests

    func testMarkdownThematicBreak() {
        let parser = SwiftParser()
        let source = "***\n"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.count, 1)
        XCTAssertEqual(result.root.children.first?.type as? MarkdownLanguage.Element, .thematicBreak)
    }

    func testMarkdownHTMLBlock() {
        let parser = SwiftParser()
        let source = "<br>"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.first?.type as? MarkdownLanguage.Element, .html)
        XCTAssertEqual(result.root.children.first?.value, "br")
    }

    func testMarkdownStrikethrough() {
        let parser = SwiftParser()
        let source = "~~strike~~"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.first?.type as? MarkdownLanguage.Element, .strikethrough)
        XCTAssertEqual(result.root.children.first?.value, "strike")
    }

    func testMarkdownTable() {
        let parser = SwiftParser()
        let source = "|a|b|\n|---|---|\n|c|d|"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        let table = result.root.children.first as? MarkdownTableNode
        XCTAssertNotNil(table)
        XCTAssertEqual(table?.children.count, 2)
        let header = table?.children.first as? MarkdownTableHeaderNode
        XCTAssertEqual(header?.children.first?.children.first?.value, "a")
        XCTAssertEqual(header?.children.last?.children.first?.value, "b")
        let row = table?.children.last as? MarkdownTableRowNode
        XCTAssertEqual(row?.children.first?.children.first?.value, "c")
        XCTAssertEqual(row?.children.last?.children.first?.value, "d")
    }

    func testMarkdownTableVariants() {
        let sources = [
            "| Name  | Age |\n|-------|-----|\n| Alice |  25 |\n| Bob   |  30 |",
            "| Name  | Age |\n|-------|:-----:|\n| Alice |  25 |\n| Bob   |  30 |",
            "| Name  | Age |\n|-------|-----|\n| Alice |  25 |\n| Bob   |  30 "
        ]
        for src in sources {
            let parser = SwiftParser()
            let result = parser.parse(src, language: MarkdownLanguage())
            XCTAssertEqual(result.errors.count, 0)
            let table = result.root.children.first as? MarkdownTableNode
            XCTAssertNotNil(table)
            XCTAssertEqual(table?.children.count, 3)
            let header = table?.children.first as? MarkdownTableHeaderNode
            XCTAssertEqual(header?.children[0].children.first?.value, "Name")
            XCTAssertEqual(header?.children[1].children.first?.value, "Age")
        }
    }

    func testMarkdownLinkReferenceDefinition() {
        let parser = SwiftParser()
        let source = "[ref]: http://example.com"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        XCTAssertEqual(result.root.children.first?.type as? MarkdownLanguage.Element, .linkReferenceDefinition)
        let def = result.root.children.first as? MarkdownLinkReferenceDefinitionNode
        XCTAssertEqual(def?.identifier, "ref")
        XCTAssertEqual(def?.url, "http://example.com")
    }

    func testMarkdownFootnoteDefinition() {
        let parser = SwiftParser()
        let source = "[^1]: footnote text"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        let node = result.root.children.first as? MarkdownFootnoteDefinitionNode
        XCTAssertEqual(node?.identifier, "1")
        XCTAssertEqual(node?.text, "footnote text")
    }

    func testMarkdownFootnoteReference() {
        let parser = SwiftParser()
        let source = "[^1]"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        let node = result.root.children.first as? MarkdownFootnoteReferenceNode
        XCTAssertEqual(node?.identifier, "1")
    }

    func testHTMLNodeClosed() {
        let parser = SwiftParser()
        let source = """
<!DOCTYPE html>
<html lang=\"en\">
<head>
  <meta charset=\"UTF-8\">
  <title>Example Page</title>
</head>
<body>
  <h1>Welcome to my webpage</h1>
</body>
</html>
"""
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        let html = result.root.children.first as? MarkdownHtmlNode
        XCTAssertEqual(html?.closed, true)
        XCTAssertEqual(html?.value, source)
    }

    func testHTMLNodeUnclosed() {
        let parser = SwiftParser()
        let source = """
<!DOCTYPE html>
<html lang=\"en\">
<head>
  <meta charset=\"UTF-8\">
  <title>Example Page</title>
</head>
<body>
  <h1>Welcome to my webpage</h1>
"""
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        let html = result.root.children.first as? MarkdownHtmlNode
        XCTAssertEqual(html?.closed, false)
        XCTAssertEqual(html?.value, source)
    }

    func testMarkdownAllFeatures() {
        let parser = SwiftParser()
        let source = """
# ATX Heading

Setext Heading
--------------

Paragraph with **strong** and *em* text, ~~strike~~, and `code`, plus [link](url) and [ref][id], auto links <http://example.com> and https://bare.com, ![alt](img.png).

line1  \nline2
line3\\
line4

&amp;&#35;&#x41;

> Quote

1. One
2. Two
   - Sub

- Bullet

***

|a|b|

<br>

```swift
print("hi")
```

~~~
tilde
~~~

    indented
    code

[id]: http://example.com
[^1]: footnote text
"""
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)

        var elements: Set<MarkdownLanguage.Element> = []
        func collect(_ node: CodeNode) {
            if let e = node.type as? MarkdownLanguage.Element {
                elements.insert(e)
            }
            for child in node.children { collect(child) }
        }
        collect(result.root)

        let expected: [MarkdownLanguage.Element] = [
            .heading, .paragraph, .orderedList, .orderedListItem,
            .emphasis, .strong, .strikethrough, .inlineCode,
            .link, .image, .blockQuote, .html, .entity
        ]
        for e in expected {
            XCTAssertTrue(elements.contains(e), "Missing \(e)")
        }
    }

    func testMarkdownInlineFormula() {
        let parser = SwiftParser()
        let source = "Inline \\(a+b\\) text"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        let para = result.root.children.first
        XCTAssertEqual(para?.children.count, 3)
        let formula = para?.children[1] as? MarkdownFormulaNode
        XCTAssertEqual(formula?.value, "a+b")
    }

    func testMarkdownDollarFormula() {
        let parser = SwiftParser()
        let source = "Equation $x+y$ here"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        let para = result.root.children.first
        let formula = para?.children[1] as? MarkdownFormulaNode
        XCTAssertEqual(formula?.value, "x+y")
    }

    func testMarkdownBracketFormula() {
        let parser = SwiftParser()
        let source = "\\[x+y\\]"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        let formula = result.root.children.first?.children.first as? MarkdownFormulaNode
        XCTAssertEqual(formula?.value, "x+y")
    }

    func testMarkdownMultiLineFormula() {
        let parser = SwiftParser()
        let source = "$$x\\ny$$"
        let result = parser.parse(source, language: MarkdownLanguage())
        XCTAssertEqual(result.errors.count, 0)
        let formula = result.root.children.first?.children.first as? MarkdownFormulaNode
        XCTAssertEqual(formula?.value, "x\\ny")
    }
}
