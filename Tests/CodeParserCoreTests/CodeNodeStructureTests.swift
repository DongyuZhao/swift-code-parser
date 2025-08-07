import Testing

@testable import CodeParserCore

@Suite("Code Node Structure Tests")
struct CodeNodeStructureTests {

  // Mock node element for testing
  enum TestNodeElement: String, CaseIterable, CodeNodeElement {
    case document = "document"
    case paragraph = "paragraph"
    case text = "text"
    case emphasis = "emphasis"
    case strong = "strong"
  }

  @Test("Basic node creation")
  func basicNodeCreation() {
    // Test that a node has the correct initial element
    let node = CodeNode<TestNodeElement>(element: .text)

    #expect(node.element == .text)
    #expect(node.parent == nil)
    #expect(node.children.isEmpty)
  }

  @Test("Append child")
  func appendChild() {
    let documentNode = CodeNode<TestNodeElement>(element: .document)
    let child = CodeNode<TestNodeElement>(element: .text)

    documentNode.append(child)

    #expect(documentNode.children.count == 1)
    #expect(documentNode.children[0].element == .text)
    #expect(child.parent === documentNode)
  }

  @Test("Insert child")
  func insertChild() {
    let documentNode = CodeNode<TestNodeElement>(element: .document)
    let child1 = CodeNode<TestNodeElement>(element: .text)
    let child2 = CodeNode<TestNodeElement>(element: .emphasis)

    documentNode.append(child1)
    documentNode.insert(child2, at: 0)

    #expect(documentNode.children.count == 2)
    #expect(documentNode.children[0].element == .emphasis)
    #expect(documentNode.children[1].element == .text)
    #expect(child2.parent === documentNode)
  }

  @Test("Remove child at index")
  func removeChildAtIndex() {
    let documentNode = CodeNode<TestNodeElement>(element: .document)
    let child1 = CodeNode<TestNodeElement>(element: .text)
    let child2 = CodeNode<TestNodeElement>(element: .emphasis)

    documentNode.append(child1)
    documentNode.append(child2)

    let removed = documentNode.remove(at: 0)

    #expect(documentNode.children.count == 1)
    #expect(documentNode.children[0].element == .emphasis)
    #expect(removed.parent == nil)
    #expect(removed.element == .text)
  }

  @Test("Remove child from parent")
  func removeChildFromParent() {
    let documentNode = CodeNode<TestNodeElement>(element: .document)
    let child1 = CodeNode<TestNodeElement>(element: .text)
    let child2 = CodeNode<TestNodeElement>(element: .emphasis)

    documentNode.append(child1)
    documentNode.append(child2)

    child1.remove()

    #expect(documentNode.children.count == 1)
    #expect(documentNode.children[0].element == .emphasis)
    #expect(child1.parent == nil)
  }

  @Test("Replace child")
  func replaceChild() {
    let documentNode = CodeNode<TestNodeElement>(element: .document)
    let originalChild = CodeNode<TestNodeElement>(element: .text)
    let newChild = CodeNode<TestNodeElement>(element: .emphasis)

    documentNode.append(originalChild)
    documentNode.replace(at: 0, with: newChild)

    #expect(documentNode.children.count == 1)
    #expect(documentNode.children[0].element == .emphasis)
    #expect(newChild.parent === documentNode)
    #expect(originalChild.parent == nil)
  }

  @Test("Depth calculation")
  func depthCalculation() {
    let documentNode = CodeNode<TestNodeElement>(element: .document)
    let child = CodeNode<TestNodeElement>(element: .paragraph)
    let grandchild = CodeNode<TestNodeElement>(element: .text)

    documentNode.append(child)
    child.append(grandchild)

    #expect(documentNode.depth == 0)
    #expect(child.depth == 1)
    #expect(grandchild.depth == 2)
  }

  @Test("Node count")
  func nodeCount() {
    let documentNode = CodeNode<TestNodeElement>(element: .document)
    let child1 = CodeNode<TestNodeElement>(element: .paragraph)
    let child2 = CodeNode<TestNodeElement>(element: .text)
    let grandchild = CodeNode<TestNodeElement>(element: .emphasis)

    documentNode.append(child1)
    documentNode.append(child2)
    child1.append(grandchild)

    #expect(documentNode.count == 4)  // document + paragraph + text + emphasis
    #expect(child1.count == 2)  // paragraph + emphasis
    #expect(child2.count == 1)  // text only
  }

  @Test("DFS traversal")
  func dfsTraversal() {
    let documentNode = CodeNode<TestNodeElement>(element: .document)
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

    #expect(visitedElements == [.document, .paragraph, .text, .emphasis, .text])
  }

  @Test("BFS traversal")
  func bfsTraversal() {
    let documentNode = CodeNode<TestNodeElement>(element: .document)
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

    #expect(visitedElements == [.document, .paragraph, .text, .text, .emphasis])
  }

  @Test("First node")
  func firstNode() {
    let documentNode = CodeNode<TestNodeElement>(element: .document)
    let paragraph = CodeNode<TestNodeElement>(element: .paragraph)
    let text = CodeNode<TestNodeElement>(element: .text)
    let emphasis = CodeNode<TestNodeElement>(element: .emphasis)

    documentNode.append(paragraph)
    paragraph.append(text)
    paragraph.append(emphasis)

    let firstEmphasis = documentNode.first { $0.element == .emphasis }
    #expect(firstEmphasis != nil)
    #expect(firstEmphasis?.element == .emphasis)

    let firstStrong = documentNode.first { $0.element == .strong }
    #expect(firstStrong == nil)
  }

  @Test("Nodes where")
  func nodesWhere() {
    let documentNode = CodeNode<TestNodeElement>(element: .document)
    let paragraph = CodeNode<TestNodeElement>(element: .paragraph)
    let text1 = CodeNode<TestNodeElement>(element: .text)
    let text2 = CodeNode<TestNodeElement>(element: .text)
    let emphasis = CodeNode<TestNodeElement>(element: .emphasis)

    documentNode.append(paragraph)
    paragraph.append(text1)
    paragraph.append(emphasis)
    documentNode.append(text2)

    let textNodes = documentNode.nodes { $0.element == .text }
    #expect(textNodes.count == 2)
    #expect(textNodes.allSatisfy { $0.element == .text })
  }

  @Test("Node ID")
  func nodeId() {
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
    #expect(node1.id != node3.id)
  }
}
