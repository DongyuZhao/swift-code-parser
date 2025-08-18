import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown Images Tests - Spec 034")
struct MarkdownImagesTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  // MARK: - Basic inline images

  @Test("Basic inline image with title")
  func basicInlineImageWithTitle() {
    let input = "![foo](/url \"title\")"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[image(url:\"/url\",alt:\"foo\",title:\"title\")]]")
  }

  @Test("Reference-style image with formatted alt text")
  func referenceStyleImageWithFormattedAltText() {
    let input = """
    ![foo *bar*]

    [foo *bar*]: train.jpg "train & tracks"
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[image(url:\"train.jpg\",alt:\"foo bar\",title:\"train & tracks\")],reference(id:\"foo *bar*\",url:\"train.jpg\",title:\"train & tracks\")]")
  }

  @Test("Image with nested image in description")
  func imageWithNestedImageInDescription() {
    let input = "![foo ![bar](/url)](/url2)"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[image(url:\"/url2\",alt:\"foo bar\",title:\"\")]]")
  }

  @Test("Image with nested link in description")
  func imageWithNestedLinkInDescription() {
    let input = "![foo [bar](/url)](/url2)"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[image(url:\"/url2\",alt:\"foo bar\",title:\"\")]]")
  }

  @Test("Collapsed reference image with formatted alt text")
  func collapsedReferenceImageWithFormattedAltText() {
    let input = """
    ![foo *bar*][]

    [foo *bar*]: train.jpg "train & tracks"
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[image(url:\"train.jpg\",alt:\"foo bar\",title:\"train & tracks\")],reference(id:\"foo *bar*\",url:\"train.jpg\",title:\"train & tracks\")]")
  }

  @Test("Full reference image with case-insensitive label")
  func fullReferenceImageWithCaseInsensitiveLabel() {
    let input = """
    ![foo *bar*][foobar]

    [FOOBAR]: train.jpg "train & tracks"
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[image(url:\"train.jpg\",alt:\"foo bar\",title:\"train & tracks\")],reference(id:\"FOOBAR\",url:\"train.jpg\",title:\"train & tracks\")]")
  }

  @Test("Simple inline image without title")
  func simpleInlineImageWithoutTitle() {
    let input = "![foo](train.jpg)"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[image(url:\"train.jpg\",alt:\"foo\",title:\"\")]]")
  }

  @Test("Inline image with whitespace around title")
  func inlineImageWithWhitespaceAroundTitle() {
    let input = "My ![foo bar](/path/to/train.jpg  \"title\"   )"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[text(\"My \"),image(url:\"/path/to/train.jpg\",alt:\"foo bar\",title:\"title\")]]")
  }

  @Test("Image with URL in angle brackets")
  func imageWithURLInAngleBrackets() {
    let input = "![foo](<url>)"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[image(url:\"url\",alt:\"foo\",title:\"\")]]")
  }

  @Test("Image with empty alt text")
  func imageWithEmptyAltText() {
    let input = "![](/url)"
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[image(url:\"/url\",alt:\"\",title:\"\")]]")
  }

  // MARK: - Reference-style images

  @Test("Full reference image")
  func fullReferenceImage() {
    let input = """
    ![foo][bar]

    [bar]: /url
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[image(url:\"/url\",alt:\"foo\",title:\"\")],reference(id:\"bar\",url:\"/url\",title:\"\")]")
  }

  @Test("Full reference image with case-insensitive matching")
  func fullReferenceImageWithCaseInsensitiveMatching() {
    let input = """
    ![foo][bar]

    [BAR]: /url
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[image(url:\"/url\",alt:\"foo\",title:\"\")],reference(id:\"BAR\",url:\"/url\",title:\"\")]")
  }

  // MARK: - Collapsed reference images

  @Test("Collapsed reference image")
  func collapsedReferenceImage() {
    let input = """
    ![foo][]

    [foo]: /url "title"
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[image(url:\"/url\",alt:\"foo\",title:\"title\")],reference(id:\"foo\",url:\"/url\",title:\"title\")]")
  }

  @Test("Collapsed reference image with formatted alt text")
  func collapsedReferenceImageWithFormattedAltTextSimple() {
    let input = """
    ![*foo* bar][]

    [*foo* bar]: /url "title"
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[image(url:\"/url\",alt:\"foo bar\",title:\"title\")],reference(id:\"*foo* bar\",url:\"/url\",title:\"title\")]")
  }

  @Test("Collapsed reference image with case-insensitive label")
  func collapsedReferenceImageWithCaseInsensitiveLabel() {
    let input = """
    ![Foo][]

    [foo]: /url "title"
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[image(url:\"/url\",alt:\"Foo\",title:\"title\")],reference(id:\"foo\",url:\"/url\",title:\"title\")]")
  }

  @Test("Collapsed reference image with whitespace between brackets")
  func collapsedReferenceImageWithWhitespaceBetweenBrackets() {
    let input = """
    ![foo]
    []

    [foo]: /url "title"
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[image(url:\"/url\",alt:\"foo\",title:\"title\"),text(\"\\n[]\")],reference(id:\"foo\",url:\"/url\",title:\"title\")]")
  }

  // MARK: - Shortcut reference images

  @Test("Shortcut reference image")
  func shortcutReferenceImage() {
    let input = """
    ![foo]

    [foo]: /url "title"
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[image(url:\"/url\",alt:\"foo\",title:\"title\")],reference(id:\"foo\",url:\"/url\",title:\"title\")]")
  }

  @Test("Shortcut reference image with formatted alt text")
  func shortcutReferenceImageWithFormattedAltText() {
    let input = """
    ![*foo* bar]

    [*foo* bar]: /url "title"
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[image(url:\"/url\",alt:\"foo bar\",title:\"title\")],reference(id:\"*foo* bar\",url:\"/url\",title:\"title\")]")
  }

  @Test("Invalid reference with unescaped brackets in label")
  func invalidReferenceWithUnescapedBracketsInLabel() {
    let input = """
    ![[foo]]

    [[foo]]: /url "title"
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[text(\"![[foo]]\")],paragraph[text(\"[[foo]]: /url \\\"title\\\"\")]]")
  }

  @Test("Shortcut reference image with case-insensitive label")
  func shortcutReferenceImageWithCaseInsensitiveLabel() {
    let input = """
    ![Foo]

    [foo]: /url "title"
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[image(url:\"/url\",alt:\"Foo\",title:\"title\")],reference(id:\"foo\",url:\"/url\",title:\"title\")]")
  }

  // MARK: - Escaped exclamation marks and brackets

  @Test("Escaped opening bracket after exclamation mark")
  func escapedOpeningBracketAfterExclamationMark() {
    let input = """
    !\\[foo]

    [foo]: /url "title"
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[text(\"![foo]\")],reference(id:\"foo\",url:\"/url\",title:\"title\")]")
  }

  @Test("Escaped exclamation mark before link")
  func escapedExclamationMarkBeforeLink() {
    let input = """
    \\![foo]

    [foo]: /url "title"
    """
    let result = parser.parse(input, language: language)
    #expect(result.errors.isEmpty)
    #expect(sig(result.root) == "document[paragraph[text(\"!\"),link(url:\"/url\",title:\"title\")[text(\"foo\")]],reference(id:\"foo\",url:\"/url\",title:\"title\")]")
  }
}
