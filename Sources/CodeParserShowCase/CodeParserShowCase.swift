#if canImport(SwiftUI)
  import SwiftUI

  @main
  struct CodeParserShowCaseApp: App {
    var body: some Scene {
      WindowGroup {
        ContentView()
      }
    }
  }

  struct ContentView: View {
    var body: some View {
      Text("Hello from CodeParserShowCase!")
        .padding()
    }
  }
#else
  @main
  struct CodeParserShowCase {
    static func main() {
      print("Hello from CodeParserShowCase!")
    }
  }
#endif
