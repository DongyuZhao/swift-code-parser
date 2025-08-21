import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Task List Items Extension Tests - Spec 026")
struct MarkdownTaskListItemsExtensionTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("Basic task list items with checked and unchecked states")
  func basicTaskListItemsWithCheckedAndUncheckedStates() {
    let input = """
    - [ ] foo
    - [x] bar
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 2)

    // First item - unchecked task
    let taskItems1 = findNodes(in: listItems[0], ofType: TaskListItemNode.self)
    #expect(taskItems1.count == 1)
    #expect(taskItems1[0].checked == false)
    #expect(innerText(taskItems1[0]) == "foo")

    // Second item - checked task
    let taskItems2 = findNodes(in: listItems[1], ofType: TaskListItemNode.self)
    #expect(taskItems2.count == 1)
    #expect(taskItems2[0].checked == true)
    #expect(innerText(taskItems2[0]) == "bar")

    let expectedSig = "document[unordered_list(level:1)[list_item[task_list_item(checked:false)[text(\"foo\")]],list_item[task_list_item(checked:true)[text(\"bar\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Nested task lists with mixed checked states")
  func nestedTaskListsWithMixedCheckedStates() {
    let input = """
    - [x] foo
      - [ ] bar
      - [x] baz
    - [ ] bim
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let topLevelItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(topLevelItems.count == 2)

    // First top-level item - checked task with nested list
    let topTask1 = findNodes(in: topLevelItems[0], ofType: TaskListItemNode.self)
    #expect(topTask1.count == 1)
    #expect(topTask1[0].checked == true)
    #expect(innerText(topTask1[0]) == "foo")

    // Nested list in first item
    let nestedLists = findNodes(in: topLevelItems[0], ofType: UnorderedListNode.self)
    #expect(nestedLists.count == 1)

    let nestedItems = findNodes(in: nestedLists[0], ofType: ListItemNode.self)
    #expect(nestedItems.count == 2)

    // First nested item - unchecked task
    let nestedTask1 = findNodes(in: nestedItems[0], ofType: TaskListItemNode.self)
    #expect(nestedTask1.count == 1)
    #expect(nestedTask1[0].checked == false)
    #expect(innerText(nestedTask1[0]) == "bar")

    // Second nested item - checked task
    let nestedTask2 = findNodes(in: nestedItems[1], ofType: TaskListItemNode.self)
    #expect(nestedTask2.count == 1)
    #expect(nestedTask2[0].checked == true)
    #expect(innerText(nestedTask2[0]) == "baz")

    // Second top-level item - unchecked task
    let topTask2 = findNodes(in: topLevelItems[1], ofType: TaskListItemNode.self)
    #expect(topTask2.count == 1)
    #expect(topTask2[0].checked == false)
    #expect(innerText(topTask2[0]) == "bim")

    let expectedSig = "document[unordered_list(level:1)[list_item[task_list_item(checked:true)[text(\"foo\")],unordered_list(level:2)[list_item[task_list_item(checked:false)[text(\"bar\")]],list_item[task_list_item(checked:true)[text(\"baz\")]]]],list_item[task_list_item(checked:false)[text(\"bim\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Task list item marker with whitespace character creates unchecked checkbox")
  func taskListItemMarkerWithWhitespaceCharacterCreatesUncheckedCheckbox() {
    let input = "- [ ] unchecked task"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)

    let taskItems = findNodes(in: listItems[0], ofType: TaskListItemNode.self)
    #expect(taskItems.count == 1)
    #expect(taskItems[0].checked == false)
    #expect(innerText(taskItems[0]) == "unchecked task")

    let expectedSig = "document[unordered_list(level:1)[list_item[task_list_item(checked:false)[text(\"unchecked task\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Task list item marker with lowercase x creates checked checkbox")
  func taskListItemMarkerWithLowercaseXCreatesCheckedCheckbox() {
    let input = "- [x] checked task with lowercase x"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)

    let taskItems = findNodes(in: listItems[0], ofType: TaskListItemNode.self)
    #expect(taskItems.count == 1)
    #expect(taskItems[0].checked == true)
    #expect(innerText(taskItems[0]) == "checked task with lowercase x")

    let expectedSig = "document[unordered_list(level:1)[list_item[task_list_item(checked:true)[text(\"checked task with lowercase x\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Task list item marker with uppercase X creates checked checkbox")
  func taskListItemMarkerWithUppercaseXCreatesCheckedCheckbox() {
    let input = "- [X] checked task with uppercase X"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)

    let taskItems = findNodes(in: listItems[0], ofType: TaskListItemNode.self)
    #expect(taskItems.count == 1)
    #expect(taskItems[0].checked == true)
    #expect(innerText(taskItems[0]) == "checked task with uppercase X")

    let expectedSig = "document[unordered_list(level:1)[list_item[task_list_item(checked:true)[text(\"checked task with uppercase X\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Task list item requires whitespace after marker before content")
  func taskListItemRequiresWhitespaceAfterMarkerBeforeContent() {
    let input = "- [ ]task without space"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    // Without proper whitespace, this should not be treated as a task list item
    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)

    let taskItems = findNodes(in: listItems[0], ofType: TaskListItemNode.self)
    #expect(taskItems.count == 0)

    let paragraphs = findNodes(in: listItems[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)
    #expect(innerText(paragraphs[0]) == "[ ]task without space")

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"[ ]task without space\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Task list item marker with optional leading spaces")
  func taskListItemMarkerWithOptionalLeadingSpaces() {
    let input = "- [ ] task with spaces before marker"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)

    let taskItems = findNodes(in: listItems[0], ofType: TaskListItemNode.self)
    #expect(taskItems.count == 1)
    #expect(taskItems[0].checked == false)
    #expect(innerText(taskItems[0]) == "task with spaces before marker")

    let expectedSig = "document[unordered_list(level:1)[list_item[task_list_item(checked:false)[text(\"task with spaces before marker\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Task list item must be first block in list item paragraph")
  func taskListItemMustBeFirstBlockInListItemParagraph() {
    let input = """
    - Some text
      [ ] this is not a task item
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)

    // Should not contain task list items since marker is not at the beginning
    let taskItems = findNodes(in: listItems[0], ofType: TaskListItemNode.self)
    #expect(taskItems.count == 0)

    let paragraphs = findNodes(in: listItems[0], ofType: ParagraphNode.self)
  #expect(paragraphs.count == 1)
  #expect(innerText(paragraphs[0]) == "Some text [ ] this is not a task item")

  let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"Some text\"),line_break(soft),text(\"[ ] this is not a task item\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Mixed task list items and regular list items")
  func mixedTaskListItemsAndRegularListItems() {
    let input = """
    - [ ] task item
    - regular item
    - [x] another task
    - another regular item
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 4)

    // First item - unchecked task
    let taskItems1 = findNodes(in: listItems[0], ofType: TaskListItemNode.self)
    #expect(taskItems1.count == 1)
    #expect(taskItems1[0].checked == false)
    #expect(innerText(taskItems1[0]) == "task item")

    // Second item - regular list item
    let taskItems2 = findNodes(in: listItems[1], ofType: TaskListItemNode.self)
    #expect(taskItems2.count == 0)
    let paragraphs2 = findNodes(in: listItems[1], ofType: ParagraphNode.self)
    #expect(paragraphs2.count == 1)
    #expect(innerText(paragraphs2[0]) == "regular item")

    // Third item - checked task
    let taskItems3 = findNodes(in: listItems[2], ofType: TaskListItemNode.self)
    #expect(taskItems3.count == 1)
    #expect(taskItems3[0].checked == true)
    #expect(innerText(taskItems3[0]) == "another task")

    // Fourth item - regular list item
    let taskItems4 = findNodes(in: listItems[3], ofType: TaskListItemNode.self)
    #expect(taskItems4.count == 0)
    let paragraphs4 = findNodes(in: listItems[3], ofType: ParagraphNode.self)
    #expect(paragraphs4.count == 1)
    #expect(innerText(paragraphs4[0]) == "another regular item")

    let expectedSig = "document[unordered_list(level:1)[list_item[task_list_item(checked:false)[text(\"task item\")]],list_item[paragraph[text(\"regular item\")]],list_item[task_list_item(checked:true)[text(\"another task\")]],list_item[paragraph[text(\"another regular item\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Task list items in ordered lists")
  func taskListItemsInOrderedLists() {
    let input = """
    1. [ ] first task
    2. [x] second task
    3. [ ] third task
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let orderedLists = findNodes(in: result.root, ofType: OrderedListNode.self)
    #expect(orderedLists.count == 1)

    let listItems = findNodes(in: orderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 3)

    // First item - unchecked task
    let taskItems1 = findNodes(in: listItems[0], ofType: TaskListItemNode.self)
    #expect(taskItems1.count == 1)
    #expect(taskItems1[0].checked == false)
    #expect(innerText(taskItems1[0]) == "first task")

    // Second item - checked task
    let taskItems2 = findNodes(in: listItems[1], ofType: TaskListItemNode.self)
    #expect(taskItems2.count == 1)
    #expect(taskItems2[0].checked == true)
    #expect(innerText(taskItems2[0]) == "second task")

    // Third item - unchecked task
    let taskItems3 = findNodes(in: listItems[2], ofType: TaskListItemNode.self)
    #expect(taskItems3.count == 1)
    #expect(taskItems3[0].checked == false)
    #expect(innerText(taskItems3[0]) == "third task")

    let expectedSig = "document[ordered_list(level:1)[list_item[task_list_item(checked:false)[text(\"first task\")]],list_item[task_list_item(checked:true)[text(\"second task\")]],list_item[task_list_item(checked:false)[text(\"third task\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Task list item with multiple whitespace characters after marker")
  func taskListItemWithMultipleWhitespaceCharactersAfterMarker() {
    let input = "- [ ]   task with multiple spaces"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)

    let taskItems = findNodes(in: listItems[0], ofType: TaskListItemNode.self)
    #expect(taskItems.count == 1)
    #expect(taskItems[0].checked == false)
    #expect(innerText(taskItems[0]) == "task with multiple spaces")

    let expectedSig = "document[unordered_list(level:1)[list_item[task_list_item(checked:false)[text(\"task with multiple spaces\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Task list item with tab character after marker")
  func taskListItemWithTabCharacterAfterMarker() {
    let input = "- [ ]\ttask with tab"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)

    let taskItems = findNodes(in: listItems[0], ofType: TaskListItemNode.self)
    #expect(taskItems.count == 1)
    #expect(taskItems[0].checked == false)
    #expect(innerText(taskItems[0]) == "task with tab")

    let expectedSig = "document[unordered_list(level:1)[list_item[task_list_item(checked:false)[text(\"task with tab\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Invalid task list item marker with wrong character")
  func invalidTaskListItemMarkerWithWrongCharacter() {
    let input = "- [y] not a valid task marker"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)

    // Should not contain task list items since 'y' is not a valid marker
    let taskItems = findNodes(in: listItems[0], ofType: TaskListItemNode.self)
    #expect(taskItems.count == 0)

    let paragraphs = findNodes(in: listItems[0], ofType: ParagraphNode.self)
    #expect(paragraphs.count == 1)
    #expect(innerText(paragraphs[0]) == "[y] not a valid task marker")

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"[y] not a valid task marker\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Task list item with complex content and formatting")
  func taskListItemWithComplexContentAndFormatting() {
    let input = "- [x] **bold task** with *emphasis* and `code`"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let unorderedLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(unorderedLists.count == 1)

    let listItems = findNodes(in: unorderedLists[0], ofType: ListItemNode.self)
    #expect(listItems.count == 1)

    let taskItems = findNodes(in: listItems[0], ofType: TaskListItemNode.self)
    #expect(taskItems.count == 1)
    #expect(taskItems[0].checked == true)

    // Check for formatted content within the task
    let strongElements = findNodes(in: taskItems[0], ofType: StrongNode.self)
    #expect(strongElements.count == 1)
    #expect(innerText(strongElements[0]) == "bold task")

    let emphasisElements = findNodes(in: taskItems[0], ofType: EmphasisNode.self)
    #expect(emphasisElements.count == 1)
    #expect(innerText(emphasisElements[0]) == "emphasis")

    let codeElements = findNodes(in: taskItems[0], ofType: CodeSpanNode.self)
    #expect(codeElements.count == 1)
    #expect(codeElements[0].code == "code")

    let expectedSig = "document[unordered_list(level:1)[list_item[task_list_item(checked:true)[strong[text(\"bold task\")],text(\" with \"),emphasis[text(\"emphasis\")],text(\" and \"),code(\"code\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Deeply nested task lists maintain proper structure")
  func deeplyNestedTaskListsMaintainProperStructure() {
    let input = """
    - [x] Level 1 checked
      - [ ] Level 2 unchecked
        - [x] Level 3 checked
          - [ ] Level 4 unchecked
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)

    let topLevelLists = findNodes(in: result.root, ofType: UnorderedListNode.self)
    #expect(topLevelLists.count == 1)

    let level1Items = findNodes(in: topLevelLists[0], ofType: ListItemNode.self)
    #expect(level1Items.count == 1)

    let level1Tasks = findNodes(in: level1Items[0], ofType: TaskListItemNode.self)
    #expect(level1Tasks.count == 1)
    #expect(level1Tasks[0].checked == true)
    #expect(innerText(level1Tasks[0]) == "Level 1 checked")

    let level2Lists = findNodes(in: level1Items[0], ofType: UnorderedListNode.self)
    #expect(level2Lists.count == 1)

    let level2Items = findNodes(in: level2Lists[0], ofType: ListItemNode.self)
    #expect(level2Items.count == 1)

    let level2Tasks = findNodes(in: level2Items[0], ofType: TaskListItemNode.self)
    #expect(level2Tasks.count == 1)
    #expect(level2Tasks[0].checked == false)
    #expect(innerText(level2Tasks[0]) == "Level 2 unchecked")

    let level3Lists = findNodes(in: level2Items[0], ofType: UnorderedListNode.self)
    #expect(level3Lists.count == 1)

    let level3Items = findNodes(in: level3Lists[0], ofType: ListItemNode.self)
    #expect(level3Items.count == 1)

    let level3Tasks = findNodes(in: level3Items[0], ofType: TaskListItemNode.self)
    #expect(level3Tasks.count == 1)
    #expect(level3Tasks[0].checked == true)
    #expect(innerText(level3Tasks[0]) == "Level 3 checked")

    let level4Lists = findNodes(in: level3Items[0], ofType: UnorderedListNode.self)
    #expect(level4Lists.count == 1)

    let level4Items = findNodes(in: level4Lists[0], ofType: ListItemNode.self)
    #expect(level4Items.count == 1)

    let level4Tasks = findNodes(in: level4Items[0], ofType: TaskListItemNode.self)
    #expect(level4Tasks.count == 1)
    #expect(level4Tasks[0].checked == false)
    #expect(innerText(level4Tasks[0]) == "Level 4 unchecked")

    let expectedSig = "document[unordered_list(level:1)[list_item[task_list_item(checked:true)[text(\"Level 1 checked\")],unordered_list(level:2)[list_item[task_list_item(checked:false)[text(\"Level 2 unchecked\")],unordered_list(level:3)[list_item[task_list_item(checked:true)[text(\"Level 3 checked\")],unordered_list(level:4)[list_item[task_list_item(checked:false)[text(\"Level 4 unchecked\")]]]]]]]]]"
    #expect(sig(result.root) == expectedSig)
  }
}
