import XCTest
@testable import CodeParser

final class ParserPipelineTests: XCTestCase {
    enum SimpleTokenElement: String, CaseIterable, CodeTokenElement {
        case number
        case plus
        case eof
    }

    struct SimpleToken: CodeToken {
        typealias Element = SimpleTokenElement
        let element: SimpleTokenElement
        let text: String
        let range: Range<String.Index>
    }

    struct NumberTokenBuilder: CodeTokenBuilder {
        typealias Token = SimpleTokenElement
        func build(from context: inout CodeTokenContext<Token>) -> Bool {
            guard context.consuming < context.source.endIndex,
                  context.source[context.consuming].isNumber else { return false }
            var end = context.consuming
            while end < context.source.endIndex && context.source[end].isNumber {
                end = context.source.index(after: end)
            }
            let range = context.consuming..<end
            let token = SimpleToken(element: .number,
                                    text: String(context.source[range]),
                                    range: range)
            context.tokens.append(token)
            context.consuming = end
            return true
        }
    }

    struct PlusTokenBuilder: CodeTokenBuilder {
        typealias Token = SimpleTokenElement
        func build(from context: inout CodeTokenContext<Token>) -> Bool {
            guard context.consuming < context.source.endIndex,
                  context.source[context.consuming] == "+" else { return false }
            let start = context.consuming
            context.consuming = context.source.index(after: start)
            let token = SimpleToken(element: .plus, text: "+", range: start..<context.consuming)
            context.tokens.append(token)
            return true
        }
    }

    struct WhitespaceTokenBuilder: CodeTokenBuilder {
        typealias Token = SimpleTokenElement
        func build(from context: inout CodeTokenContext<Token>) -> Bool {
            guard context.consuming < context.source.endIndex,
                  context.source[context.consuming].isWhitespace else { return false }
            context.consuming = context.source.index(after: context.consuming)
            return true
        }
    }

    enum SimpleNodeElement: String, CaseIterable, CodeNodeElement {
        case root
        case number
    }

    struct NumberNodeBuilder: CodeNodeBuilder {
        typealias Node = SimpleNodeElement
        typealias Token = SimpleTokenElement
        func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
            guard context.consuming < context.tokens.count,
                  let token = context.tokens[context.consuming] as? SimpleToken,
                  token.element == .number else { return false }
            let node = CodeNode<Node>(element: .number)
            context.current.append(node)
            context.consuming += 1
            return true
        }
    }

    struct SimpleLanguage: CodeLanguage {
        typealias Node = SimpleNodeElement
        typealias Token = SimpleTokenElement

        var tokens: [any CodeTokenBuilder<Token>] {
            [WhitespaceTokenBuilder(), NumberTokenBuilder(), PlusTokenBuilder()]
        }
        var nodes: [any CodeNodeBuilder<Node, Token>] { [NumberNodeBuilder()] }

        func root() -> CodeNode<Node> { CodeNode<Node>(element: .root) }
        func state() -> (any CodeConstructState<Node, Token>)? { nil }
        func state() -> (any CodeTokenState<Token>)? { nil }
        // rely on default eof implementation
    }

    func testTokenizerProducesTokensAndErrors() {
        let tokenizer = CodeTokenizer(
            builders: [NumberTokenBuilder(), PlusTokenBuilder()],
            state: { nil },
            eof: { SimpleToken(element: .eof, text: "", range: $0) }
        )

        let (tokens, errors) = tokenizer.tokenize("1+a")
        XCTAssertEqual(tokens.count, 3) // number, plus, eof
        XCTAssertEqual((tokens[0] as? SimpleToken)?.text, "1")
        XCTAssertEqual((tokens[1] as? SimpleToken)?.element, .plus)
        XCTAssertEqual((tokens[2] as? SimpleToken)?.element, .eof)
        XCTAssertEqual(errors.count, 1)
    }

    func testConstructorBuildsNodesAndErrors() {
        let oneRange = "1".startIndex..<"1".endIndex
        let plusRange = "+".startIndex..<"+".endIndex
        let twoRange = "2".startIndex..<"2".endIndex
        let tokens: [any CodeToken<SimpleTokenElement>] = [
            SimpleToken(element: .number, text: "1", range: oneRange),
            SimpleToken(element: .plus, text: "+", range: plusRange),
            SimpleToken(element: .number, text: "2", range: twoRange)
        ]
        let root = CodeNode<SimpleNodeElement>(element: .root)
        let constructor = CodeConstructor(builders: [NumberNodeBuilder()], state: { nil })
        let (parsed, errors) = constructor.parse(tokens, root: root)
        XCTAssertEqual(parsed.children.count, 2)
        XCTAssertEqual(errors.count, 1) // plus token unrecognized
    }

    func testParserNormalizesAndParses() {
        let language = SimpleLanguage()
        let parser = CodeParser(language: language)
        let result = parser.parse("1\r\n2\r", language: language)
        XCTAssertEqual(result.root.children.count, 2)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertEqual(result.tokens.count, 2)
        // ensure default eof returns nil
        XCTAssertNil(language.eof(at: "".startIndex..<"".endIndex))
    }

    func testContextAndErrorInitialization() {
        let tokenContext = CodeTokenContext<SimpleTokenElement>(source: "1")
        XCTAssertEqual(tokenContext.source, "1")
        XCTAssertTrue(tokenContext.tokens.isEmpty)
        XCTAssertTrue(tokenContext.errors.isEmpty)

        let root = CodeNode<SimpleNodeElement>(element: .root)
        let constructContext = CodeConstructContext<SimpleNodeElement, SimpleTokenElement>(
            current: root, tokens: []
        )
        XCTAssertTrue(constructContext.current === root)
        XCTAssertEqual(constructContext.tokens.count, 0)
        XCTAssertEqual(constructContext.consuming, 0)
        XCTAssertTrue(constructContext.errors.isEmpty)

        let error = CodeError("msg", range: "a".startIndex..<"a".startIndex)
        XCTAssertEqual(error.message, "msg")
        XCTAssertNotNil(error.range)
    }
}
