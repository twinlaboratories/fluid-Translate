import SwiftUI

struct PersonView: View {
    @Binding var selectedLanguage: Language
    @ObservedObject var geminiService: GeminiService
    var isUpsideDown: Bool
    var allowSavedPhrases: Bool
    var onToggle: () -> Void
    var onSendText: ((String, Language, Bool) -> Void)?
    
    @State private var inputText: String = ""
    @State private var showPhrases: Bool = false
    @State private var phrases: [String] = []
    @State private var newPhrase: String = ""
    @FocusState private var isInputFocused: Bool
    
    var filteredMessages: [ChatMessage] {
        geminiService.messages
    }
    
    var body: some View {
        ZStack {
            // Liquid Background
            Color.black.ignoresSafeArea()
            
            // Content
            VStack(spacing: 0) {
                // Header
                HStack {
                    // Language Picker
                    Menu {
                        ForEach(AVAILABLE_LANGUAGES) { lang in
                            Button(action: {
                                selectedLanguage = lang
                                loadPhrases()
                            }) {
                                HStack {
                                    Text(lang.name)
                                    if selectedLanguage.id == lang.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedLanguage.name)
                                .foregroundColor(.white)
                            Image(systemName: "chevron.down")
                                .foregroundColor(.white)
                                .font(.system(size: 12))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(geminiService.isConnected)
                    
                    // Saved Phrases Button
                    if allowSavedPhrases {
                        Button(action: {
                            showPhrases = true
                        }) {
                            Image(systemName: "bookmark.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 16))
                                .padding(8)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    
                    Spacer()
                    
                    // Connection Status
                    if geminiService.isConnected {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("LIVE")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                    
                    // Connect Button
                    Button(action: onToggle) {
                        Image(systemName: geminiService.isConnected ? "mic.fill" : "mic.slash.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 50, height: 50)
                            .background(
                                Circle()
                                    .fill(geminiService.isConnected ? Color.red : Color.blue)
                                    .shadow(color: geminiService.isConnected ? .red.opacity(0.5) : .blue.opacity(0.5), radius: 10)
                            )
                    }
                    .disabled(geminiService.isConnecting)
                }
                .padding()
                .background(.thinMaterial)
                
                // Messages (Chat Stream)
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            if filteredMessages.isEmpty {
                                VStack {
                                    Spacer()
                                    Text("Tap mic to speak or type below to interpret.")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                        .padding()
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                ForEach(filteredMessages) { msg in
                                    MessageBubble(message: msg)
                                        .id(msg.id)
                                }
                            }
                        }
                        .padding()
                    }
                    .onChange(of: filteredMessages.count) { _ in
                        if let last = filteredMessages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Footer / Visualizer
                if geminiService.isConnected {
                    VStack {
                        AudioVisualizer(level: geminiService.audioLevel, color: .blue)
                            .frame(height: 40)
                    }
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                    )
                }
                
                // Input Area
                HStack(spacing: 8) {
                    TextField("Type in \(selectedLanguage.name)...", text: $inputText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .focused($isInputFocused)
                        .onChange(of: inputText) { newValue in
                            onSendText?(newValue, selectedLanguage, false)
                        }
                        .onSubmit {
                            handleFinalize()
                        }
                    
                    Button(action: handleFinalize) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                .background(.thinMaterial)
            }
        }
        .rotationEffect(isUpsideDown ? .degrees(180) : .degrees(0))
        .sheet(isPresented: $showPhrases) {
            SavedPhrasesView(
                phrases: $phrases,
                newPhrase: $newPhrase,
                language: selectedLanguage,
                onPhraseSelect: { phrase in
                    onSendText?(phrase, selectedLanguage, true)
                    showPhrases = false
                }
            )
        }
        .onAppear {
            loadPhrases()
        }
        .onChange(of: selectedLanguage.id) { _ in
            loadPhrases()
        }
    }
    
    private func handleFinalize() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            onSendText?(text, selectedLanguage, true)
            inputText = ""
        }
    }
    
    private func loadPhrases() {
        let key = "phrases-\(selectedLanguage.code)"
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([String].self, from: data) {
            phrases = saved
        } else {
            phrases = ["Hello", "Thank you", "Yes", "No", "I don't understand", "Please"]
        }
    }
}

struct SavedPhrasesView: View {
    @Binding var phrases: [String]
    @Binding var newPhrase: String
    let language: Language
    let onPhraseSelect: (String) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                List {
                    ForEach(phrases.indices, id: \.self) { index in
                        Button(action: {
                            onPhraseSelect(phrases[index])
                        }) {
                            HStack {
                                Text(phrases[index])
                                    .foregroundColor(.primary)
                                Spacer()
                                Button(action: {
                                    phrases.remove(at: index)
                                    savePhrases()
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
                
                HStack {
                    TextField("Add new phrase...", text: $newPhrase)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            addPhrase()
                        }
                    
                    Button(action: addPhrase) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                    }
                    .disabled(newPhrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                .background(.thinMaterial)
            }
            .navigationTitle("Saved Phrases (\(language.name))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addPhrase() {
        let phrase = newPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        if !phrase.isEmpty {
            phrases.append(phrase)
            newPhrase = ""
            savePhrases()
        }
    }
    
    private func savePhrases() {
        let key = "phrases-\(language.code)"
        if let data = try? JSONEncoder().encode(phrases) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

