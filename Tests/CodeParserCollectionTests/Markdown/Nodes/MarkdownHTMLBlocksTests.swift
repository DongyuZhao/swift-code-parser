import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("Markdown HTML Blocks Tests - Spec 019")
struct MarkdownHTMLBlocksTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  @Test("HTML block type 6 with table tag followed by paragraph")
  func basicTableHTMLBlock() {
    let input = """
<table>
  <tr>
    <td>
           hi
    </td>
  </tr>
</table>

okay.
"""
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[html_block(name:\"\",content:\"<table>\n  <tr>\n    <td>\n           hi\n    </td>\n  </tr>\n</table>\"),paragraph[text(\"okay.\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("HTML block type 6 with div tag containing literal content")
  func divHTMLBlockWithLiteralContent() {
    let input = """
 <div>
  *hello*
         <foo><a>
"""
    let result = parser.parse(input, language: language)

    // No emphasis should be parsed inside HTML block

    // Verify AST structure using sig
    let expectedSig = "document[html_block(name:\"\",content:\" <div>\n  *hello*\n         <foo><a>\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("HTML block starting with closing tag")
  func closingTagStartsHTMLBlock() {
    let input = """
</div>
*foo*
"""
    let result = parser.parse(input, language: language)

    // No emphasis should be parsed inside HTML block

    // Verify AST structure using sig
    let expectedSig = "document[html_block(name:\"\",content:\"</div>\n*foo*\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("HTML blocks separated by blank line with Markdown in between")
  func htmlBlocksWithMarkdownBetween() {
    let input = """
<DIV CLASS="foo">

*Markdown*

</DIV>
"""
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[html_block(name:\"\",content:\"<DIV CLASS=\\\"foo\\\">\"),paragraph[emphasis[text(\"Markdown\")]],html_block(name:\"\",content:\"</DIV>\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Partial tag split across lines")
  func partialTagSplitAcrossLines() {
    let input = """
<div id="foo"
  class="bar">
</div>
"""
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[html_block(name:\"\",content:\"<div id=\\\"foo\\\"\n  class=\\\"bar\\\">\n</div>\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Partial tag with attribute split across lines")
  func partialTagWithAttributeSplit() {
    let input = """
<div id="foo" class="bar
  baz">
</div>
"""
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[html_block(name:\"\",content:\"<div id=\\\"foo\\\" class=\\\"bar\n  baz\\\">\n</div>\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Open tag without closing tag")
  func openTagWithoutClosing() {
    let input = """
<div>
*foo*

*bar*
"""
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[html_block(name:\"\",content:\"<div>\n*foo*\"),paragraph[emphasis[text(\"bar\")]]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Incomplete partial tag")
  func incompletePartialTag() {
    let input = """
<div id="foo"
*hi*
"""
    let result = parser.parse(input, language: language)

    // No emphasis should be parsed inside HTML block

    // Verify AST structure using sig
    let expectedSig = "document[html_block(name:\"\",content:\"<div id=\\\"foo\\\"\n*hi*\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Invalid tag structure still treated as HTML block")
  func invalidTagStructure() {
    let input = """
<div *???-&&&-<---
*foo*
"""
    let result = parser.parse(input, language: language)

    // No emphasis should be parsed inside HTML block

    // Verify AST structure using sig
    let expectedSig = "document[html_block(name:\"\",content:\"<div *???-&&&-<---\n*foo*\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Single line HTML block type 6")
  func singleLineHTMLBlock() {
    let input = "<div><a href=\"bar\">*foo*</a></div>"
    let result = parser.parse(input, language: language)

    // No emphasis should be parsed inside HTML block

    // Verify AST structure using sig
    let expectedSig = "document[html_block(name:\"\",content:\"<div><a href=\\\"bar\\\">*foo*</a></div>\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Table HTML block continues until blank line")
  func tableHTMLBlockContinuation() {
    let input = """
<table><tr><td>
foo
</td></tr></table>
"""
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[html_block(name:\"\",content:\"<table><tr><td>\nfoo\n</td></tr></table>\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("HTML block includes fenced code block")
  func htmlBlockIncludesFencedCode() {
    let input = """
<div></div>
``` c
int x = 33;
```
"""
    let result = parser.parse(input, language: language)

    // No separate code block should be created

    // Verify AST structure using sig
    let expectedSig = "document[html_block(name:\"\",content:\"<div></div>\n``` c\nint x = 33;\n```\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("HTML block type 7 with custom tag on separate line")
  func type7HTMLBlockCustomTag() {
    let input = """
<a href="foo">
*bar*
</a>
"""
    let result = parser.parse(input, language: language)

    // No emphasis should be parsed inside HTML block

    // Verify AST structure using sig
    let expectedSig = "document[html_block(name:\"\",content:\"<a href=\\\"foo\\\">\n*bar*\n</a>\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("HTML block type 7 with Warning tag")
  func type7HTMLBlockWarningTag() {
    let input = """
<Warning>
*bar*
</Warning>
"""
    let result = parser.parse(input, language: language)

    // No emphasis should be parsed inside HTML block

    // Verify AST structure using sig
    let expectedSig = "document[html_block(name:\"\",content:\"<Warning>\n*bar*\n</Warning>\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("HTML block with del tag containing Markdown")
  func delTagHTMLBlock() {
    let input = """
<del>
*foo*
</del>
"""
    let result = parser.parse(input, language: language)

    // No emphasis should be parsed inside HTML block

    // Verify AST structure using sig
    let expectedSig = "document[html_block(name:\"\",content:\"<del>\n*foo*\n</del>\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("HTML block with del tag and blank line allows Markdown")
  func delTagWithBlankLineAllowsMarkdown() {
    let input = """
<del>

*foo*

</del>
"""
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[html_block(name:\"\",content:\"<del>\"),paragraph[emphasis[text(\"foo\")]],html_block(name:\"\",content:\"</del>\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("Inline HTML when tag is not on separate line")
  func inlineHTMLWhenNotOnSeparateLine() {
    let input = "<del>*foo*</del>"
    let result = parser.parse(input, language: language)

    // Should be parsed as paragraph with inline HTML and emphasis

    // Verify AST structure using sig
    let expectedSig = "document[paragraph[html(\"<del>\"),emphasis[text(\"foo\")],html(\"</del>\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("HTML block type 1 with pre tag")
  func type1HTMLBlockPreTag() {
    let input = """
<pre language="haskell"><code>
import Text.HTML.TagSoup

main :: IO ()
main = print $ parseTags tags
</code></pre>
okay
"""
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[html_block(name:\"\",content:\"<pre language=\\\"haskell\\\"><code>\nimport Text.HTML.TagSoup\n\nmain :: IO ()\nmain = print $ parseTags tags\n</code></pre>\"),paragraph[text(\"okay\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("HTML block type 1 with script tag")
  func type1HTMLBlockScriptTag() {
    let input = """
<script type="text/javascript">
// JavaScript example

document.getElementById("demo").innerHTML = "Hello JavaScript!";
</script>
okay
"""
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[html_block(name:\"\",content:\"<script type=\\\"text/javascript\\\">\n// JavaScript example\n\ndocument.getElementById(\\\"demo\\\").innerHTML = \\\"Hello JavaScript!\\\";\n</script>\"),paragraph[text(\"okay\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("HTML block type 1 with style tag")
  func type1HTMLBlockStyleTag() {
    let input = """
<style
  type="text/css">
h1 {color:red;}

p {color:blue;}
</style>
okay
"""
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[html_block(name:\"\",content:\"<style\n  type=\\\"text/css\\\">\nh1 {color:red;}\n\np {color:blue;}\n</style>\"),paragraph[text(\"okay\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("HTML block type 2 with comment")
  func type2HTMLBlockComment() {
    let input = """
<!-- Foo

bar
   baz -->
okay
"""
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[html_block(name:\"\",content:\"<!-- Foo\n\nbar\n   baz -->\"),paragraph[text(\"okay\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("HTML block type 3 with processing instruction")
  func type3HTMLBlockProcessingInstruction() {
    let input = """
<?php

  echo '>';

?>
okay
"""
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[html_block(name:\"\",content:\"<?php\n\n  echo '>';\n\n?>\"),paragraph[text(\"okay\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("HTML block type 4 with declaration")
  func type4HTMLBlockDeclaration() {
    let input = "<!DOCTYPE html>"
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[html_block(name:\"\",content:\"<!DOCTYPE html>\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("HTML block type 5 with CDATA")
  func type5HTMLBlockCDATA() {
    let input = """
<![CDATA[
function matchwo(a,b)
{
  if (a < b && a < 0) then {
    return 1;

  } else {

    return 0;
  }
}
]]>
okay
"""
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[html_block(name:\"\",content:\"<![CDATA[\nfunction matchwo(a,b)\n{\n  if (a < b && a < 0) then {\n    return 1;\n\n  } else {\n\n    return 0;\n  }\n}\n]]>\"),paragraph[text(\"okay\")]]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("HTML block indentation up to 3 spaces allowed")
  func htmlBlockIndentationAllowed() {
    let input = """
  <!-- foo -->

    <!-- foo -->
"""
    let result = parser.parse(input, language: language)

    // Verify AST structure using sig
    let expectedSig = "document[html_block(name:\"\",content:\"  <!-- foo -->\"),code_block(\"&lt;!-- foo --&gt;\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("HTML block can interrupt paragraph")
  func htmlBlockCanInterruptParagraph() {
    let input = """
Foo
<div>
bar
</div>
"""
    let result = parser.parse(input, language: language)

  // Verify AST structure using sig
  let expectedSig = "document[paragraph[text(\"Foo\")],html_block(name:\"\",content:\"<div>\nbar\n</div>\")]"
    #expect(sig(result.root) == expectedSig)
  }

  @Test("HTML block type 7 cannot interrupt paragraph")
  func type7CannotInterruptParagraph() {
    let input = """
Foo
<a href="bar">
baz
"""
    let result = parser.parse(input, language: language)

  // Verify AST structure using sig
  let expectedSig = "document[paragraph[text(\"Foo\"),line_break(soft),html(\"<a href=\\\"bar\\\">\"),line_break(soft),text(\"baz\")]]"
    #expect(sig(result.root) == expectedSig)
  }
}
