import XCTest
@testable import CodeParser

final class CodeNodeStructureTests: XCTestCase {

    // Mock node element for testing
    enum TestNodeElement: String, CaseIterable, CodeNodeElement {
        case document = "document"
        case paragraph = "paragraph"
        case text = "text"
        case emphasis = "emphasis"
        case strong = "strong"
    }

    var documentNode: CodeNode<TestNodeElement>!

    override func setUp() {
        super.setUp()
        documentNode = CodeNode<TestNodeElement>(element: .document)
    }

    override func tearDown() {
        documentNode = nil
        super.tearDown()
    }

    func testBasicNodeCreation() {
        // Test that a node has the correct initial element
        let node = CodeNode<TestNodeElement>(element: .text)

        XCTAssertEqual(node.element, .text)
        XCTAssertNil(node.parent)
        XCTAssertTrue(node.children.isEmpty)
    }

    func testAppendChild() {
        let child = CodeNode<TestNodeElement>(element: .text)

        documentNode.append(child)

        XCTAssertEqual(documentNode.children.count, 1)
        XCTAssertEqual(documentNode.children[0].element, .text)
        XCTAssertTrue(child.parent === documentNode)
    }

    func testInsertChild() {
        let child1 = CodeNode<TestNodeElement>(element: .text)
        let child2 = CodeNode<TestNodeElement>(element: .emphasis)

        documentNode.append(child1)
        documentNode.insert(child2, at: 0)

        XCTAssertEqual(documentNode.children.count, 2)
        XCTAssertEqual(documentNode.children[0].element, .emphasis)
        XCTAssertEqual(documentNode.children[1].element, .text)
        XCTAssertTrue(child2.parent === documentNode)
    }

    func testRemoveChildAtIndex() {
        let child1 = CodeNode<TestNodeElement>(element: .text)
        let child2 = CodeNode<TestNodeElement>(element: .emphasis)

        documentNode.append(child1)
        documentNode.append(child2)

        let removed = documentNode.remove(at: 0)

        XCTAssertEqual(documentNode.children.count, 1)
        XCTAssertEqual(documentNode.children[0].element, .emphasis)
        XCTAssertNil(removed.parent)
        XCTAssertEqual(removed.element, .text)
    }

    func testRemoveChildFromParent() {
        let child1 = CodeNode<TestNodeElement>(element: .text)
        let child2 = CodeNode<TestNodeElement>(element: .emphasis)

        documentNode.append(child1)
        documentNode.append(child2)

        child1.remove()

        XCTAssertEqual(documentNode.children.count, 1)
        XCTAssertEqual(documentNode.children[0].element, .emphasis)
        XCTAssertNil(child1.parent)
    }

    func testReplaceChild() {
        let originalChild = CodeNode<TestNodeElement>(element: .text)
        let newChild = CodeNode<TestNodeElement>(element: .emphasis)

        documentNode.append(originalChild)
        documentNode.replace(at: 0, with: newChild)

        XCTAssertEqual(documentNode.children.count, 1)
        XCTAssertEqual(documentNode.children[0].element, .emphasis)
        XCTAssertTrue(newChild.parent === documentNode)
        XCTAssertNil(originalChild.parent)
    }

    func testDepthCalculation() {
        let child = CodeNode<TestNodeElement>(element: .paragraph)
        let grandchild = CodeNode<TestNodeElement>(element: .text)

        documentNode.append(child)
        child.append(grandchild)

        XCTAssertEqual(documentNode.depth, 0)
        XCTAssertEqual(child.depth, 1)
        XCTAssertEqual(grandchild.depth, 2)
    }

    func testNodeCount() {
        let child1 = CodeNode<TestNodeElement>(element: .paragraph)
        let child2 = CodeNode<TestNodeElement>(element: .text)
        let grandchild = CodeNode<TestNodeElement>(element: .emphasis)

        documentNode.append(child1)
        documentNode.append(child2)
        child1.append(grandchild)

        XCTAssertEqual(documentNode.count, 4) // document + paragraph + text + emphasis
        XCTAssertEqual(child1.count, 2) // paragraph + emphasis
        XCTAssertEqual(child2.count, 1) // text only
    }

    func testDFSTraversal() {
        let paragraph = CodeNode<TestNodeElement>(element: .paragraph)
        let text1 = CodeNode<TestNodeElement>(element: .text)
        let emphasis = CodeNode<TestNodeElement>(element: .emphasis)
        let text2 = CodeNode<TestNodeElement>(element: .text)

        documentNode.append(paragraph)
        paragraph.append(text1)
        paragraph.append(emphasis)
        documentNode.append(text2)

        var visitedElements: [TestNodeElement] = []
        documentNode.dfs { node in
            visitedElements.append(node.element)
        }

        XCTAssertEqual(visitedElements, [.document, .paragraph, .text, .emphasis, .text])
    }

    func testBFSTraversal() {
        let paragraph = CodeNode<TestNodeElement>(element: .paragraph)
        let text1 = CodeNode<TestNodeElement>(element: .text)
        let emphasis = CodeNode<TestNodeElement>(element: .emphasis)
        let text2 = CodeNode<TestNodeElement>(element: .text)

        documentNode.append(paragraph)
        paragraph.append(text1)
        paragraph.append(emphasis)
        documentNode.append(text2)

        var visitedElements: [TestNodeElement] = []
        documentNode.bfs { node in
            visitedElements.append(node.element)
        }

        XCTAssertEqual(visitedElements, [.document, .paragraph, .text, .text, .emphasis])
    }

    func testFirstNode() {
        let paragraph = CodeNode<TestNodeElement>(element: .paragraph)
        let text = CodeNode<TestNodeElement>(element: .text)
        let emphasis = CodeNode<TestNodeElement>(element: .emphasis)

        documentNode.append(paragraph)
        paragraph.append(text)
        paragraph.append(emphasis)

        let firstEmphasis = documentNode.first { $0.element == .emphasis }
        XCTAssertNotNil(firstEmphasis)
        XCTAssertEqual(firstEmphasis?.element, .emphasis)

        let firstStrong = documentNode.first { $0.element == .strong }
        XCTAssertNil(firstStrong)
    }

    func testNodesWhere() {
        let paragraph = CodeNode<TestNodeElement>(element: .paragraph)
        let text1 = CodeNode<TestNodeElement>(element: .text)
        let text2 = CodeNode<TestNodeElement>(element: .text)
        let emphasis = CodeNode<TestNodeElement>(element: .emphasis)

        documentNode.append(paragraph)
        paragraph.append(text1)
        paragraph.append(emphasis)
        documentNode.append(text2)

        let textNodes = documentNode.nodes { $0.element == .text }
        XCTAssertEqual(textNodes.count, 2)
        XCTAssertTrue(textNodes.allSatisfy { $0.element == .text })
    }

    func testNodeId() {
        let node1 = CodeNode<TestNodeElement>(element: .text)
        let node2 = CodeNode<TestNodeElement>(element: .text)
        let node3 = CodeNode<TestNodeElement>(element: .emphasis)

        // Same element type should have same base hash (before children)
        // But different instances may have different IDs due to implementation details

        // Add same children to both nodes
        let child1a = CodeNode<TestNodeElement>(element: .strong)
        let child1b = CodeNode<TestNodeElement>(element: .strong)

        node1.append(child1a)
        node2.append(child1b)

        // Different element types should have different IDs
        XCTAssertNotEqual(node1.id, node3.id)
    }
}
