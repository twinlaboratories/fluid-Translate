import Foundation
import AVFoundation
import Combine

class GeminiService: NSObject, ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isConnected: Bool = false
    @Published var isConnecting: Bool = false
    @Published var audioLevel: Float = 0.0
    @Published var error: String?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var inputFormat: AVAudioFormat?
    private var converter: AVAudioConverter?
    
    // Audio playback management
    private var nextStartTime: AVAudioTime?
    private var audioSources: Set<AVAudioPlayerNode> = []
    private let audioQueue = DispatchQueue(label: "com.duotranslate.audio")
    
    // Transcription state
    private var currentInputTranscription: String = ""
    private var currentOutputTranscription: String = ""
    private var currentUserId: String?
    private var currentModelId: String?
    
    // Text translation state
    private var draftSessions: [String: DraftSession] = [:]
    
    // Gemini Config
    private var apiKey: String {
        return AppConfig.geminiAPIKey
    }
    
    private let model = "gemini-2.5-flash-native-audio-preview-09-2025"
    
    struct DraftSession {
        let userId: String
        let modelId: String
        var timeoutTask: DispatchWorkItem?
        var abortController: URLSessionDataTask?
    }
    
    override init() {
        super.init()
        setupAudio()
    }
    
    private func setupAudio() {
        // Setup audio engine for playback
        audioEngine.attach(playerNode)
        let mainMixer = audioEngine.mainMixerNode
        audioEngine.connect(playerNode, to: mainMixer, format: nil)
        
        do {
            try audioEngine.start()
        } catch {
            print("Audio Engine failed to start: \(error)")
        }
    }
    
    func connect(lang1: Language, lang2: Language) {
        guard !apiKey.isEmpty else {
            DispatchQueue.main.async {
                self.error = "API key not configured. Please set GEMINI_API_KEY environment variable."
            }
            return
        }
        
        isConnecting = true
        error = nil
        
        let urlString = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                self.error = "Invalid WebSocket URL"
                self.isConnecting = false
            }
            return
        }
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        receiveMessage()
        
        // Send Initial Setup Message
        sendSetupMessage(lang1: lang1, lang2: lang2)
        
        // Start Microphone
        startRecording()
        
        DispatchQueue.main.async {
            self.isConnected = true
            self.isConnecting = false
        }
    }
    
    func disconnect() {
        stopRecording()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        
        // Stop all audio playback
        audioQueue.async {
            self.audioSources.forEach { $0.stop() }
            self.audioSources.removeAll()
        }
        
        DispatchQueue.main.async {
            self.isConnected = false
            self.isConnecting = false
            self.messages.removeAll()
            self.audioLevel = 0.0
            
            // Reset transcription state
            self.currentInputTranscription = ""
            self.currentOutputTranscription = ""
            self.currentUserId = nil
            self.currentModelId = nil
        }
    }
    
    // MARK: - Text Entry Handler
    
    func handleTextEntry(_ text: String, srcLang: Language, isFinal: Bool) {
        let draftKey = srcLang.code
        let tgtLang = srcLang.code == AVAILABLE_LANGUAGES[0].code ? AVAILABLE_LANGUAGES[1] : AVAILABLE_LANGUAGES[0]
        
        // Initialize draft session if needed
        if draftSessions[draftKey] == nil {
            let idBase = "\(Date().timeIntervalSince1970)-\(UUID().uuidString.prefix(6))"
            draftSessions[draftKey] = DraftSession(
                userId: "\(idBase)-user",
                modelId: "\(idBase)-model",
                timeoutTask: nil,
                abortController: nil
            )
        }
        
        guard var session = draftSessions[draftKey] else { return }
        
        // Handle empty text (deletion)
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            DispatchQueue.main.async {
                self.messages.removeAll { $0.id == session.userId || $0.id == session.modelId }
            }
            session.timeoutTask?.cancel()
            draftSessions.removeValue(forKey: draftKey)
            return
        }
        
        // Update user message immediately
        DispatchQueue.main.async {
            let userMsg = ChatMessage(
                id: session.userId,
                text: text,
                sender: .user,
                isFinal: isFinal,
                isDraft: !isFinal,
                type: .text
            )
            
            let existingModelMsg = self.messages.first { $0.id == session.modelId }
            let modelMsg = ChatMessage(
                id: session.modelId,
                text: existingModelMsg?.text ?? "...",
                sender: .model,
                isFinal: isFinal,
                isDraft: !isFinal,
                type: .text
            )
            
            if let userIndex = self.messages.firstIndex(where: { $0.id == session.userId }) {
                self.messages[userIndex] = userMsg
                if isFinal, let modelIndex = self.messages.firstIndex(where: { $0.id == session.modelId }) {
                    self.messages[modelIndex] = modelMsg
                }
            } else {
                self.messages.append(userMsg)
                self.messages.append(modelMsg)
            }
        }
        
        // Handle finalization
        if isFinal {
            session.timeoutTask?.cancel()
            performTranslation(text: text, src: srcLang, tgt: tgtLang, session: session, isFinal: true)
            draftSessions.removeValue(forKey: draftKey)
            return
        }
        
        // Debounced translation
        session.timeoutTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.performTranslation(text: text, src: srcLang, tgt: tgtLang, session: session, isFinal: false)
        }
        session.timeoutTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: task)
        draftSessions[draftKey] = session
    }
    
    private func performTranslation(text: String, src: Language, tgt: Language, session: DraftSession, isFinal: Bool) {
        // Use Gemini API for text translation
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=\(apiKey)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "Translate to \(tgt.name). Only output the translation. Text: \(text)"]
                    ]
                ]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                if !(error as NSError).userInfo.keys.contains(NSURLErrorCancelledKey) {
                    DispatchQueue.main.async {
                        self.error = "Translation error: \(error.localizedDescription)"
                    }
                }
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first,
                  let content = firstCandidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let firstPart = parts.first,
                  let translatedText = firstPart["text"] as? String else {
                return
            }
            
            DispatchQueue.main.async {
                if let index = self.messages.firstIndex(where: { $0.id == session.modelId }) {
                    self.messages[index].text = translatedText
                    self.messages[index].isFinal = isFinal
                    self.messages[index].isDraft = !isFinal
                }
                self.error = nil
            }
        }
        
        task.resume()
    }
    
    // MARK: - WebSocket Logic
    
    private func sendSetupMessage(lang1: Language, lang2: Language) {
        let setupJSON: [String: Any] = [
            "setup": [
                "model": "models/\(model)",
                "generationConfig": [
                    "responseModalities": ["AUDIO"],
                    "speechConfig": [
                        "voiceConfig": [
                            "prebuiltVoiceConfig": ["voiceName": "Kore"]
                        ]
                    ]
                ],
                "systemInstruction": [
                    "parts": [
                        [
                            "text": "You are a real-time interpreter. Translate spoken audio between \(lang1.name) and \(lang2.name). Rules: 1. When you hear \(lang1.name), translate to \(lang2.name). 2. When you hear \(lang2.name), translate to \(lang1.name). 3. Speak immediately. 4. Speak quickly and efficiently. Increase your speaking rate slightly to be faster than normal conversation. 5. Keep translations short and direct. 6. Do not answer questions or engage in conversation, ONLY TRANSLATE. 7. If audio is unintelligible, stay silent."
                        ]
                    ]
                ],
                "inputAudioTranscription": [:],
                "outputAudioTranscription": [:]
            ]
        ]
        sendJSON(setupJSON)
    }
    
    private func sendJSON(_ json: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let string = String(data: data, encoding: .utf8) else { return }
        let message = URLSessionWebSocketTask.Message.string(string)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("WebSocket Send Error: \(error)")
                DispatchQueue.main.async {
                    self.error = "Connection error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self, self.isConnected else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleServerResponse(text)
                case .data(let data):
                    print("Received binary data: \(data.count) bytes")
                @unknown default:
                    break
                }
                self.receiveMessage() // Continue receiving
            case .failure(let error):
                print("WebSocket Error: \(error)")
                DispatchQueue.main.async {
                    self.isConnected = false
                    self.error = "Connection lost: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func handleServerResponse(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        // Handle input transcription (user speech)
        if let serverContent = json["serverContent"] as? [String: Any],
           let inputTranscription = serverContent["inputTranscription"] as? [String: Any],
           let text = inputTranscription["text"] as? String, !text.isEmpty {
            
            currentInputTranscription += text
            
            DispatchQueue.main.async {
                if let currentId = self.currentUserId {
                    if let index = self.messages.firstIndex(where: { $0.id == currentId }) {
                        self.messages[index].text = self.currentInputTranscription
                    }
                } else {
                    let newId = "\(Date().timeIntervalSince1970)-user-audio"
                    self.currentUserId = newId
                    self.messages.append(ChatMessage(
                        id: newId,
                        text: self.currentInputTranscription,
                        sender: .user,
                        isFinal: false,
                        isDraft: true,
                        type: .audio
                    ))
                }
            }
        }
        
        // Handle output transcription (model translation)
        if let serverContent = json["serverContent"] as? [String: Any],
           let outputTranscription = serverContent["outputTranscription"] as? [String: Any],
           let text = outputTranscription["text"] as? String, !text.isEmpty {
            
            currentOutputTranscription += text
            
            DispatchQueue.main.async {
                if let currentId = self.currentModelId {
                    if let index = self.messages.firstIndex(where: { $0.id == currentId }) {
                        self.messages[index].text = self.currentOutputTranscription
                    }
                } else {
                    let newId = "\(Date().timeIntervalSince1970)-model-audio"
                    self.currentModelId = newId
                    self.messages.append(ChatMessage(
                        id: newId,
                        text: self.currentOutputTranscription,
                        sender: .model,
                        isFinal: false,
                        isDraft: true,
                        type: .audio
                    ))
                }
            }
        }
        
        // Handle turn complete
        if let serverContent = json["serverContent"] as? [String: Any],
           serverContent["turnComplete"] != nil {
            
            DispatchQueue.main.async {
                self.messages = self.messages.map { msg in
                    if (self.currentUserId != nil && msg.id == self.currentUserId) ||
                       (self.currentModelId != nil && msg.id == self.currentModelId) {
                        var updated = msg
                        updated.isFinal = true
                        updated.isDraft = false
                        return updated
                    }
                    return msg
                }
                
                // Reset for next turn
                self.currentInputTranscription = ""
                self.currentOutputTranscription = ""
                self.currentUserId = nil
                self.currentModelId = nil
            }
        }
        
        // Handle audio output
        if let serverContent = json["serverContent"] as? [String: Any],
           let modelTurn = serverContent["modelTurn"] as? [String: Any],
           let parts = modelTurn["parts"] as? [[String: Any]],
           let firstPart = parts.first,
           let inlineData = firstPart["inlineData"] as? [String: Any],
           let base64Audio = inlineData["data"] as? String,
           let audioData = Data(base64Encoded: base64Audio) {
            
            playAudio(data: audioData)
        }
    }
    
    // MARK: - Audio Handling
    
    private func startRecording() {
        // Request microphone permission
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            guard granted, let self = self else {
                DispatchQueue.main.async {
                    self?.error = "Microphone permission denied"
                }
                return
            }
            
            do {
                try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                DispatchQueue.main.async {
                    self.error = "Failed to configure audio session: \(error.localizedDescription)"
                }
                return
            }
            
            let inputNode = self.audioEngine.inputNode
            let nativeFormat = inputNode.inputFormat(forBus: 0)
            
            // Create 16kHz format for Gemini
            guard let format16k = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true) else {
                DispatchQueue.main.async {
                    self.error = "Failed to create audio format"
                }
                return
            }
            
            guard let converter = AVAudioConverter(from: nativeFormat, to: format16k) else {
                DispatchQueue.main.async {
                    self.error = "Failed to create audio converter"
                }
                return
            }
            
            self.converter = converter
            self.inputFormat = nativeFormat
            
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: nativeFormat) { [weak self] (buffer, time) in
                guard let self = self else { return }
                
                // Calculate audio level (RMS)
                if let channelData = buffer.floatChannelData?[0] {
                    let frameLength = Int(buffer.frameLength)
                    var sum: Float = 0
                    for i in 0..<frameLength {
                        sum += channelData[i] * channelData[i]
                    }
                    let rms = sqrt(sum / Float(frameLength))
                    DispatchQueue.main.async {
                        self.audioLevel = min(rms * 50, 1.0) // Normalize to 0-1
                    }
                }
                
                // Convert and send audio
                let capacity = AVAudioFrameCount(Double(format16k.sampleRate) * 0.1) // 100ms
                guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format16k, frameCapacity: capacity) else { return }
                
                var error: NSError?
                let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }
                
                converter.convert(to: pcmBuffer, error: &error, withInputFrom: inputBlock)
                
                if let error = error {
                    print("Audio conversion error: \(error)")
                    return
                }
                
                if let channelData = pcmBuffer.int16ChannelData {
                    let data = Data(bytes: channelData[0], count: Int(pcmBuffer.frameLength) * 2)
                    let base64 = data.base64EncodedString()
                    
                    let msgJSON: [String: Any] = [
                        "realtimeInput": [
                            "mediaChunks": [
                                [
                                    "mimeType": "audio/pcm;rate=16000",
                                    "data": base64
                                ]
                            ]
                        ]
                    ]
                    self.sendJSON(msgJSON)
                }
            }
        }
    }
    
    private func stopRecording() {
        audioEngine.inputNode.removeTap(onBus: 0)
    }
    
    private func playAudio(data: Data) {
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Gemini returns 24kHz PCM audio
            let sampleRate: Double = 24000
            let channels: UInt32 = 1
            
            // Convert Int16 PCM data to Float32
            let int16Data = data.withUnsafeBytes { Array(UnsafeBufferPointer<Int16>(start: $0.baseAddress?.assumingMemoryBound(to: Int16.self), count: data.count / 2)) }
            let frameCount = int16Data.count
            
            guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: channels, interleaved: false),
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
                return
            }
            
            buffer.frameLength = AVAudioFrameCount(frameCount)
            
            if let channelData = buffer.floatChannelData {
                for i in 0..<frameCount {
                    channelData[0][i] = Float(int16Data[i]) / 32768.0
                }
            }
            
            // Schedule playback
            let startTime = self.nextStartTime ?? AVAudioTime(sampleTime: 0, atRate: sampleRate)
            self.playerNode.scheduleBuffer(buffer, at: startTime, options: []) {
                // Calculate next start time
                let duration = Double(frameCount) / sampleRate
                self.nextStartTime = AVAudioTime(sampleTime: startTime.sampleTime + AVAudioFramePosition(duration * sampleRate), atRate: sampleRate)
            }
            
            if !self.playerNode.isPlaying {
                self.playerNode.play()
            }
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension GeminiService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("WebSocket connected")
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("WebSocket closed: \(closeCode)")
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
}

