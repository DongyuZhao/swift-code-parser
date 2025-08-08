import CodeParserCollection
import CodeParserCore
import SwiftUI

@MainActor
final class CodeParserPlugin: ObservableObject, WorkbenchPlugin {
  // WorkbenchPlugin
  let id: String = "code-parser"
  let title: String = "Code Parser"
  let icon: String = "doc.text.magnifyingglass"

  // State
  @Published var selectedLanguage: DemoLanguage = .markdown
  @Published var selectedTab: MainTab = .ast
  @Published var inputText: String = {
    """
    # Hello CodeParser!

    This is a **demo** of the CodeParser framework.

    - Feature 1: Markdown parsing
    - Feature 2: Token analysis
    - Feature 3: AST construction
    """
  }()
  @Published var parseResult: CodeParseResult<MarkdownNodeElement, MarkdownTokenElement>?
  @Published var caretLine: Int = 1
  @Published var caretColumn: Int = 1
  @Published var lineEnding: String = "LF"
  @Published var textEncoding: String = "UTF-8"
  // Collections
  @Published var collections: [WorkbenchCollection] = CollectionStore.load()
  @Published var selectedCollectionID: UUID? = nil
  @Published var selectedFileID: UUID? = nil

  // Parser
  private let language = MarkdownLanguage()
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>

  init() {
    parser = CodeParser(language: language)
    parse()
  }

  enum MainTab: Int, CaseIterable {
    case richText = 0
    case html, tokens, ast
  }

  func sidebar() -> AnyView { AnyView(CodeParserSidebar(plugin: self)) }

  func canvas() -> AnyView {
    AnyView(CodeParserCanvas(plugin: self))
  }

  func statusBar() -> AnyView { AnyView(CodeParserStatusBar(plugin: self)) }

  func parse() {
    guard selectedLanguage == .markdown else {
      parseResult = nil
      return
    }
    parseResult = parser.parse(inputText, language: language)
  }

  // MARK: - Collections Ops
  func addCollection() {
    let newCol = WorkbenchCollection(name: "Collection \(collections.count + 1)")
    collections.append(newCol)
    CollectionStore.save(collections)
  }
  func removeCollection(_ id: UUID) {
    collections.removeAll { $0.id == id }
    if selectedCollectionID == id {
      selectedCollectionID = nil
      selectedFileID = nil
    }
    CollectionStore.save(collections)
  }
  func addFile(to id: UUID) {
    guard let idx = collections.firstIndex(where: { $0.id == id }) else { return }
    let file = WorkbenchFile(name: "untitled.md", content: inputText)
    collections[idx].files.append(file)
    CollectionStore.save(collections)
  }
  func removeFile(_ fid: UUID, in cid: UUID) {
    guard let cidx = collections.firstIndex(where: { $0.id == cid }) else { return }
    collections[cidx].files.removeAll { $0.id == fid }
    if selectedFileID == fid { selectedFileID = nil }
    CollectionStore.save(collections)
  }
  func open(file: WorkbenchFile) {
    inputText = file.content
    selectedLanguage = .detect(from: file.name)
    parse()
  }
}

// MARK: - Views

private struct CodeParserSidebar: View {
  @ObservedObject var plugin: CodeParserPlugin

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Explorer").font(.headline)
        Spacer()
        Button(action: { plugin.addCollection() }) {
          Image(systemName: "plus")
        }.buttonStyle(.plain)
      }
      .padding(.horizontal)

      List(selection: Binding(get: { plugin.selectedFileID }, set: { plugin.selectedFileID = $0 }))
      {
        ForEach(plugin.collections) { col in
          Section(
            header: HStack {
              Text(col.name)
              Spacer()
              Button(action: { plugin.addFile(to: col.id) }) { Image(systemName: "doc.badge.plus") }
                .buttonStyle(.plain)
              Button(role: .destructive, action: { plugin.removeCollection(col.id) }) {
                Image(systemName: "trash")
              }.buttonStyle(.plain)
            }
          ) {
            ForEach(col.files) { file in
              Button(action: { plugin.open(file: file) }) {
                HStack {
                  Image(systemName: "doc.text")
                  Text(file.name)
                }
              }.buttonStyle(.plain)
                .contextMenu {
                  Button(role: .destructive) {
                    plugin.removeFile(file.id, in: col.id)
                  } label: {
                    Label("Delete", systemImage: "trash")
                  }
                }
            }
          }
        }
      }
      .listStyle(.inset)
      .frame(minWidth: 240)
    }
  }
}

private struct CodeParserStatusBar: View {
  @ObservedObject var plugin: CodeParserPlugin

  var body: some View {
    StatusBarView(
      selectedLanguage: Binding(
        get: { plugin.selectedLanguage }, set: { plugin.selectedLanguage = $0 }),
      caretLine: plugin.caretLine,
      caretColumn: plugin.caretColumn,
      encoding: Binding(get: { plugin.textEncoding }, set: { plugin.textEncoding = $0 }),
      lineEnding: Binding(get: { plugin.lineEnding }, set: { plugin.lineEnding = $0 }),
      onParse: { plugin.parse() }
    )
    .onChange(of: plugin.selectedLanguage) { _, _ in plugin.parse() }
  }
}

private struct CodeParserCanvas: View {
  @ObservedObject var plugin: CodeParserPlugin

  var body: some View {
    ResizableSplitView(
      minLeading: 400, minTrailing: 320, initialProportion: 0.6, handleWidth: 5,
      leading: {
        // Center editor + header
        VStack(spacing: 0) {
          headerBar
          #if os(macOS)
            CodeEditorView(text: $plugin.inputText) { line, col in
              plugin.caretLine = line
              plugin.caretColumn = col
            }
            .padding(.horizontal)
            .padding(.bottom)
            .frame(minWidth: 400, idealWidth: 600, maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
          #else
            TextEditor(text: $plugin.inputText)
              .font(.system(.body, design: .monospaced))
              .padding(8)
              .background(Color(UIColor.systemBackground))
              .cornerRadius(8)
              .padding(.horizontal)
              .padding(.bottom)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          #endif
        }
      },
      trailing: {
        // Right inspectors (tabs)
        VStack(spacing: 0) {
          Picker("View", selection: $plugin.selectedTab) {
            Text("RichText").tag(CodeParserPlugin.MainTab.richText)
            Text("HTML").tag(CodeParserPlugin.MainTab.html)
            Text("Token").tag(CodeParserPlugin.MainTab.tokens)
            Text("AST").tag(CodeParserPlugin.MainTab.ast)
          }
          .pickerStyle(.segmented)
          .padding(.horizontal)
          .padding(.bottom, 8)

          Group {  // content area
            switch plugin.selectedTab {
            case .richText:
              RichTextView(markdown: plugin.inputText)
                .padding(.bottom)
            case .html:
              HTMLView(parseResult: plugin.parseResult)
                .padding(.bottom)
            case .tokens:
              TokensView(parseResult: plugin.parseResult)
                .padding(.bottom)
            case .ast:
              VStack(alignment: .leading) {
                Text("Abstract Syntax Tree").font(.headline).padding(.horizontal)
                TreeView(parseResult: plugin.parseResult)
              }
              .padding(.bottom)
            }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 320)
      }
    )
  }

  private var headerBar: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .center) {
        Text("Code Parser Visualizer").font(.title2).bold()
        Spacer()
        Button(action: { plugin.parse() }) { Label("Parse", systemImage: "play.circle.fill") }
          .buttonStyle(.borderedProminent)
      }
      HStack(spacing: 8) {
        Label(plugin.selectedLanguage.rawValue, systemImage: plugin.selectedLanguage.iconName)
          .font(.subheadline).foregroundColor(.secondary)
        Spacer()
      }
    }
    .padding(.horizontal)
    .padding(.top, 12)
    .padding(.bottom, 8)
  }
}
