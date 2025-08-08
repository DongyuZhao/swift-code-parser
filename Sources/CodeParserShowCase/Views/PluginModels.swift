import Foundation

struct WorkbenchFile: Codable, Identifiable, Equatable {
  var id: UUID
  var name: String // filename with extension
  var content: String
  var createdAt: Date
  var updatedAt: Date

  init(id: UUID = UUID(), name: String, content: String, createdAt: Date = Date(), updatedAt: Date = Date()) {
    self.id = id
    self.name = name
    self.content = content
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

struct WorkbenchCollection: Codable, Identifiable, Equatable {
  var id: UUID
  var name: String
  var files: [WorkbenchFile]

  init(id: UUID = UUID(), name: String, files: [WorkbenchFile] = []) {
    self.id = id
    self.name = name
    self.files = files
  }
}

enum CollectionStore {
  static func storageURL() -> URL {
    let fm = FileManager.default
    #if os(macOS)
    let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let dir = base.appendingPathComponent("swift-code-parser", isDirectory: true)
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("collections.json")
    #else
    return fm.urls(for: .documentDirectory, in: .userDomainMask).first!
      .appendingPathComponent("collections.json")
    #endif
  }

  static func load() -> [WorkbenchCollection] {
    let url = storageURL()
    guard let data = try? Data(contentsOf: url) else { return [] }
    return (try? JSONDecoder().decode([WorkbenchCollection].self, from: data)) ?? []
  }

  static func save(_ collections: [WorkbenchCollection]) {
    let url = storageURL()
    if let data = try? JSONEncoder().encode(collections) {
      try? data.write(to: url)
    }
  }
}

extension DemoLanguage {
  static func detect(from filename: String) -> DemoLanguage {
    let ext = (filename as NSString).pathExtension.lowercased()
    switch ext {
    case "md", "markdown": return .markdown
    case "swift": return .swift
    case "json": return .json
    case "xml": return .xml
    default: return .markdown
    }
  }
}
