import SwiftUI

struct SidebarView: View {
    @Binding var selectedLanguage: LanguageOption
    
    var body: some View {
        List(LanguageOption.allCases, id: \.self, selection: $selectedLanguage) { language in
            NavigationLink(value: language) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(language.displayName)
                            .font(.headline)
                        Text(language.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: language.iconName)
                        .foregroundStyle(language.color)
                }
            }
        }
        .navigationTitle("Languages")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    NavigationView {
        SidebarView(selectedLanguage: .constant(.markdown))
    }
}
