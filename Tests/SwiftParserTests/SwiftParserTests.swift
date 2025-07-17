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
}
