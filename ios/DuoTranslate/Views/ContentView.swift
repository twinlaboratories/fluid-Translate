import SwiftUI

struct ContentView: View {
    @StateObject private var geminiService = GeminiService()
    @State private var lang1 = AVAILABLE_LANGUAGES[0] // English
    @State private var lang2 = AVAILABLE_LANGUAGES[1] // Spanish
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Person (Rotated 180)
            PersonView(
                selectedLanguage: $lang2,
                geminiService: geminiService,
                isUpsideDown: true,
                allowSavedPhrases: false,
                onToggle: toggleConnection,
                onSendText: handleTextEntry
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Divider with Error Display
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                
                if let error = geminiService.error {
                    Text(error)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            
            // Bottom Person (Normal)
            PersonView(
                selectedLanguage: $lang1,
                geminiService: geminiService,
                isUpsideDown: false,
                allowSavedPhrases: true,
                onToggle: toggleConnection,
                onSendText: handleTextEntry
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.black)
        .statusBarHidden()
    }
    
    func toggleConnection() {
        if geminiService.isConnected {
            geminiService.disconnect()
        } else {
            geminiService.connect(lang1: lang1, lang2: lang2)
        }
    }
    
    func handleTextEntry(_ text: String, _ lang: Language, _ isFinal: Bool) {
        geminiService.handleTextEntry(text, srcLang: lang, isFinal: isFinal)
    }
}

