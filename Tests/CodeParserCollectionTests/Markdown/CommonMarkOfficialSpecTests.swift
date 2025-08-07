import Foundation
import Testing

@testable import CodeParserCollection
@testable import CodeParserCore

// Basic driver to download and iterate CommonMark official spec examples (spec.json).
// It currently only asserts that examples can be parsed without fatal errors and collects
// a lightweight per-section pass count. Future work: compare produced HTML (requires renderer).
@Suite("CommonMark Official Spec Examples")
struct CommonMarkOfficialSpecTests {
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private let language: MarkdownLanguage

  init() {
    language = MarkdownLanguage()
    parser = CodeParser(language: language)
  }

  struct Spec: Decodable { let examples: [Example] }
  struct Example: Decodable { let markdown: String; let html: String; let section: String; let number: Int }

  // Location to cache the downloaded spec to avoid repeated network fetches during local runs.
  private func cacheURL() -> URL {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    return tmp.appendingPathComponent("commonmark-spec-cache", isDirectory: true)
      .appendingPathComponent("spec.json")
  }

  private func loadSpec() throws -> Spec {
    let url = cacheURL()
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: url.deletingLastPathComponent().path) {
      try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    }
    // Download if not cached (simple heuristic: size < 1KB -> redownload)
    var data: Data
    if let attrs = try? fileManager.attributesOfItem(atPath: url.path),
       let size = attrs[.size] as? NSNumber, size.intValue > 1024, let cached = try? Data(contentsOf: url) {
      data = cached
    } else {
      let remote = URL(string: "https://raw.githubusercontent.com/commonmark/commonmark-spec/master/spec.json")!
      data = try Data(contentsOf: remote)
      try? data.write(to: url, options: .atomic)
    }
    return try JSONDecoder().decode(Spec.self, from: data)
  }

  @Test("Download and parse CommonMark spec examples (smoke)")
  func downloadAndParseExamples() throws {
    // Attempt to load spec; if network blocked, mark issue but don't hard-fail entire suite.
    let spec: Spec
    do { spec = try loadSpec() } catch {
      Issue.record("Failed to load commonmark spec.json: \(error)")
      return
    }
    #expect(spec.examples.count > 600, "Spec example count seems too low: \(spec.examples.count)")

    var parseErrorExamples: [Int] = []
    var emptyRootExamples: [Int] = []
    var sectionCounts: [String: Int] = [:]

    for ex in spec.examples { // Keep fast: avoid heavy assertions per example.
      let result = parser.parse(ex.markdown, language: language)
      if !result.errors.isEmpty { parseErrorExamples.append(ex.number) }
      if result.root.children.isEmpty && !ex.markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        emptyRootExamples.append(ex.number)
      }
      sectionCounts[ex.section, default: 0] += 1
    }

    // We currently allow parse errors (unimplemented features) but surface statistics.
    if !parseErrorExamples.isEmpty {
      Issue.record("Examples with parser errors: count=\(parseErrorExamples.count) e.g. first 5: \(parseErrorExamples.prefix(5))")
    }
    if !emptyRootExamples.isEmpty {
      Issue.record("Examples produced empty root unexpectedly: count=\(emptyRootExamples.count) e.g. first 5: \(emptyRootExamples.prefix(5))")
    }

    // Minimal sanity: majority examples should not error.
    #expect(parseErrorExamples.count < spec.examples.count / 2, "Too many spec examples produced parse errors: \(parseErrorExamples.count)")
  }
}
