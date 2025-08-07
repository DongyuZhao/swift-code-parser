import SwiftUI

struct HeaderView: View {
    let selectedLanguage: LanguageOption
    let onParseAction: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("CodeParser ShowCase")
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack(spacing: 8) {
                    Image(systemName: selectedLanguage.iconName)
                        .foregroundStyle(selectedLanguage.color)
                    Text(selectedLanguage.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onParseAction) {
                Label("Parse", systemImage: "play.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

#Preview {
    HeaderView(selectedLanguage: .markdown) {
        print("Parse tapped")
    }
}
