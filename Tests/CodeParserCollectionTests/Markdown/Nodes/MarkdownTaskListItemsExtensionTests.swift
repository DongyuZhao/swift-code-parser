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

    let expectedSig = "document[unordered_list(level:1)[list_item[task_list_item(checked:true)[text(\"foo\")],unordered_list(level:2)[list_item[task_list_item(checked:false)[text(\"bar\")]],list_item[task_list_item(checked:true)[text(\"baz\")]]]],list_item[task_list_item(checked:false)[text(\"bim\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Task list item marker with whitespace character creates unchecked checkbox")
  func taskListItemMarkerWithWhitespaceCharacterCreatesUncheckedCheckbox() {
    let input = "- [ ] unchecked task"
    let result = parser.parse(input, language: language)

    let expectedSig = "document[unordered_list(level:1)[list_item[task_list_item(checked:false)[text(\"unchecked task\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Task list item marker with lowercase x creates checked checkbox")
  func taskListItemMarkerWithLowercaseXCreatesCheckedCheckbox() {
    let input = "- [x] checked task with lowercase x"
    let result = parser.parse(input, language: language)

    let expectedSig = "document[unordered_list(level:1)[list_item[task_list_item(checked:true)[text(\"checked task with lowercase x\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Task list item marker with uppercase X creates checked checkbox")
  func taskListItemMarkerWithUppercaseXCreatesCheckedCheckbox() {
    let input = "- [X] checked task with uppercase X"
    let result = parser.parse(input, language: language)

    let expectedSig = "document[unordered_list(level:1)[list_item[task_list_item(checked:true)[text(\"checked task with uppercase X\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Task list item requires whitespace after marker before content")
  func taskListItemRequiresWhitespaceAfterMarkerBeforeContent() {
    let input = "- [ ]task without space"
    let result = parser.parse(input, language: language)

    // Without proper whitespace, this should not be treated as a task list item

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"[ ]task without space\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Task list item marker with optional leading spaces")
  func taskListItemMarkerWithOptionalLeadingSpaces() {
    let input = "- [ ] task with spaces before marker"
    let result = parser.parse(input, language: language)

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

    // Should not contain task list items since marker is not at the beginning

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

    // First item - unchecked task

    // Second item - regular list item

    // Third item - checked task

    // Fourth item - regular list item

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

    // First item - unchecked task

    // Second item - checked task

    // Third item - unchecked task

    let expectedSig = "document[ordered_list(level:1)[list_item[task_list_item(checked:false)[text(\"first task\")]],list_item[task_list_item(checked:true)[text(\"second task\")]],list_item[task_list_item(checked:false)[text(\"third task\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Task list item with multiple whitespace characters after marker")
  func taskListItemWithMultipleWhitespaceCharactersAfterMarker() {
    let input = "- [ ]   task with multiple spaces"
    let result = parser.parse(input, language: language)

    let expectedSig = "document[unordered_list(level:1)[list_item[task_list_item(checked:false)[text(\"task with multiple spaces\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Task list item with tab character after marker")
  func taskListItemWithTabCharacterAfterMarker() {
    let input = "- [ ]\ttask with tab"
    let result = parser.parse(input, language: language)

    let expectedSig = "document[unordered_list(level:1)[list_item[task_list_item(checked:false)[text(\"task with tab\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Invalid task list item marker with wrong character")
  func invalidTaskListItemMarkerWithWrongCharacter() {
    let input = "- [y] not a valid task marker"
    let result = parser.parse(input, language: language)

    // Should not contain task list items since 'y' is not a valid marker

    let expectedSig = "document[unordered_list(level:1)[list_item[paragraph[text(\"[y] not a valid task marker\")]]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Task list item with complex content and formatting")
  func taskListItemWithComplexContentAndFormatting() {
    let input = "- [x] **bold task** with *emphasis* and `code`"
    let result = parser.parse(input, language: language)

    // Check for formatted content within the task

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

    let expectedSig = "document[unordered_list(level:1)[list_item[task_list_item(checked:true)[text(\"Level 1 checked\")],unordered_list(level:2)[list_item[task_list_item(checked:false)[text(\"Level 2 unchecked\")],unordered_list(level:3)[list_item[task_list_item(checked:true)[text(\"Level 3 checked\")],unordered_list(level:4)[list_item[task_list_item(checked:false)[text(\"Level 4 unchecked\")]]]]]]]]]"
    #expect(sig(result.root) == expectedSig)
  }
}
