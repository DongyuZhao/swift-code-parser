import SwiftUI

// 供各插件共享的语言选择（示例）
enum DemoLanguage: String, CaseIterable, Identifiable {
  case markdown = "Markdown"
  case swift = "Swift"
  case json = "JSON"
  case xml = "XML"
  var id: String { rawValue }

  var iconName: String {
    switch self {
    case .markdown: return "doc.richtext"
    case .swift: return "swift"
    case .json: return "curlybraces"
    case .xml: return "chevron.left.forwardslash.chevron.right"
    }
  }
}

// VSCode 风格工作台插件接口
@MainActor
protocol WorkbenchPlugin: Identifiable {
  var id: String { get }
  var title: String { get }
  var icon: String { get } // SF Symbols name

  func sidebar() -> AnyView
  func canvas() -> AnyView
  func statusBar() -> AnyView // 可为空视图
}

extension WorkbenchPlugin {
  func statusBar() -> AnyView { AnyView(EmptyView()) }
}

// 插件注册器
@MainActor
final class WorkbenchRegistry: ObservableObject {
  @Published var plugins: [any WorkbenchPlugin]
  @Published var selectedPluginID: String

  init(plugins: [any WorkbenchPlugin]) {
    self.plugins = plugins
    self.selectedPluginID = plugins.first?.id ?? ""
  }

  var selected: (any WorkbenchPlugin)? {
    plugins.first { $0.id == selectedPluginID }
  }
}
