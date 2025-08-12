import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

@Suite("CommonMark - Images (Strict)")
struct MarkdownCommonMarkImagesTests {
  private let h = MarkdownTestHarness()

  @Test("Inline image with exact structure")
  func inlineImage() {
    let input = "See ![Alt text](image.png) here."
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    #expect(result.root.children.count == 1)
    guard let para = result.root.children.first as? ParagraphNode else { Issue.record("Expected ParagraphNode"); return }
    #expect(para.children.count == 3)
    #expect((para.children[0] as? TextNode)?.content == "See ")
    guard let image = para.children[1] as? ImageNode else { Issue.record("Expected ImageNode at position 1"); return }
    #expect(image.url == "image.png")
    #expect(image.alt == "Alt text")
    #expect((para.children[2] as? TextNode)?.content == " here.")
  }

  @Test("Reference-style image resolves")
  func referenceImage() {
    let input = "See ![Alt text][img] here.\n\n[img]: image.png \"Image Title\""
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    let images = findNodes(in: result.root, ofType: ImageNode.self)
    #expect(images.count == 1)
    if let refImage = images.first {
      #expect(refImage.url == "image.png")
      #expect(refImage.alt == "Alt text")
      #expect(refImage.title == "Image Title")
    }
  }

  @Test("Image with title")
  func imageWithTitle() {
    let input = "![Alt text](image.png \"Image Title\")"
    let result = h.parser.parse(input, language: h.language)
    #expect(result.errors.isEmpty)
    let images = findNodes(in: result.root, ofType: ImageNode.self)
    #expect(images.count == 1)
    if let image = images.first { #expect(image.title == "Image Title") }
  }
}
