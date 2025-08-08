//
//  ContentView.swift
//  CodeParserShowCase
//
//  Root view for the SwiftUI demo app.
//

#if canImport(SwiftUI)
import SwiftUI
import CodeParserCore
import CodeParserCollection

struct ContentView: View {
  @StateObject private var registry = WorkbenchRegistry(plugins: [CodeParserPlugin()])

  // Back-compat simple activity bar: use plugin list as icons
  @State private var selectedActivityIndex: Int = 0

  var body: some View {
    #if os(macOS)
    // macOS: VSCode-style layout using split views
    VStack(spacing: 0) {
  ResizableSplitView(minLeading: 260, minTrailing: 320, initialProportion: 0.28, handleWidth: 5,
        leading: {
          // Left region = ActivityBar + Sidebar Canvas
          HStack(spacing: 0) {
            ActivityBarDynamicView(registry: registry, selectedIndex: $selectedActivityIndex)
            Divider()
            if let plugin = registry.selected as? CodeParserPlugin { // 当前仅一个插件
              plugin.sidebar()
            } else {
              AnyView(EmptyView())
            }
          }
          .frame(minWidth: 260)
        },
        trailing: {
          // Right region = Main Canvas (Editor + Inspectors Tabs)
          ResizableSplitView(minLeading: 400, minTrailing: 320, initialProportion: 0.62, handleWidth: 5,
            leading: {
              if let plugin = registry.selected { plugin.canvas() }
            },
            trailing: {
              // 右侧由插件自行实现；此处预留空列以便可分割
              EmptyView().frame(minWidth: 320)
            }
          )
        }
      )
      // Status bar below the canvases
      if let plugin = registry.selected { plugin.statusBar() }
    }
    .background(contentBackground)
    .onAppear { /* plugins setup already parsed */ }
    #else
    // 其他平台：简化为当前插件的画布 + 状态栏
    VStack(spacing: 0) {
      if let plugin = registry.selected { plugin.canvas() }
      if let plugin = registry.selected { plugin.statusBar() }
    }
    #endif
  }

  // MARK: - Helpers

  private var contentBackground: Color {
    #if os(macOS)
    Color(NSColor.windowBackgroundColor)
    #else
    Color(UIColor.systemBackground)
    #endif
  }

}

#endif

// MARK: - VSCode-like subviews

// (旧版 ActivityBarView/SideBarCanvasView 已移除，改为插件驱动的 ActivityBarDynamicView)

// MARK: - Status Bar

#if canImport(SwiftUI)
struct StatusBarView: View {
  @Binding var selectedLanguage: DemoLanguage
  var caretLine: Int
  var caretColumn: Int
  @Binding var encoding: String
  @Binding var lineEnding: String
  var onParse: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      // Left: language selector placed in status bar
      HStack(spacing: 6) {
        Image(systemName: "chevron.left.forwardslash.chevron.right")
        Picker("Language", selection: $selectedLanguage) {
          ForEach(DemoLanguage.allCases, id: \.self) { lang in
            Text(lang.rawValue).tag(lang)
          }
        }
        .labelsHidden()
        .frame(width: 160)
      }

      Divider().frame(height: 14)

      Button(action: onParse) {
        Label("Parse", systemImage: "play.fill")
      }
      .buttonStyle(.bordered)

      Spacer()

      // Right: indicators and toggles
      Label("Ln \(caretLine), Col \(caretColumn)", systemImage: "text.cursor")
        .foregroundColor(.secondary)
      Picker("Encoding", selection: $encoding) {
        Text("UTF-8").tag("UTF-8")
        Text("UTF-16").tag("UTF-16")
        Text("ASCII").tag("ASCII")
      }
      .labelsHidden()
      .frame(width: 90)
      Picker("EOL", selection: $lineEnding) {
        Text("LF").tag("LF")
        Text("CRLF").tag("CRLF")
      }
      .labelsHidden()
      .frame(width: 70)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(statusBarBackground)
  }

  private var statusBarBackground: Color {
    #if os(macOS)
    return Color(NSColor.underPageBackgroundColor)
    #else
    return Color(UIColor.secondarySystemBackground)
    #endif
  }
}
#endif

// MARK: - Dynamic Activity Bar (Plugin-driven)

#if canImport(SwiftUI)
struct ActivityBarDynamicView: View {
  @ObservedObject var registry: WorkbenchRegistry
  @Binding var selectedIndex: Int

  var body: some View {
    VStack(spacing: 8) {
  ForEach(Array(registry.plugins.enumerated()), id: \.offset) { index, plugin in
        Button(action: {
          selectedIndex = index
          registry.selectedPluginID = plugin.id
        }) {
          Image(systemName: plugin.icon)
            .font(.system(size: 16, weight: .semibold))
            .frame(width: 32, height: 32)
            .foregroundColor(currentSelected(plugin) ? .white : .primary)
            .background(currentSelected(plugin) ? Color.accentColor : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .help(plugin.title)
        }
        .buttonStyle(.plain)
      }
      Spacer()
      Image(systemName: "gearshape").foregroundColor(.secondary).padding(.bottom, 8)
    }
    .padding(.vertical, 8)
    .frame(width: 48)
    .background(Color(NSColor.windowBackgroundColor))
  }

  private func currentSelected(_ plugin: any WorkbenchPlugin) -> Bool {
    registry.selected?.id == plugin.id
  }
}
#endif
