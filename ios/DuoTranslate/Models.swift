import Foundation

struct Language: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let voiceName: String
    
    var code: String { id }
}

let AVAILABLE_LANGUAGES: [Language] = [
    Language(id: "en-US", name: "English", voiceName: "Puck"),
    Language(id: "es-ES", name: "Spanish", voiceName: "Kore"),
    Language(id: "fr-FR", name: "French", voiceName: "Charon"),
    Language(id: "de-DE", name: "German", voiceName: "Fenrir"),
    Language(id: "ja-JP", name: "Japanese", voiceName: "Zephyr"),
    Language(id: "ko-KR", name: "Korean", voiceName: "Puck"),
    Language(id: "zh-CN", name: "Chinese (Mandarin)", voiceName: "Kore"),
    Language(id: "ur-PK", name: "Urdu", voiceName: "Charon"),
    Language(id: "pa-IN", name: "Punjabi", voiceName: "Fenrir")
]

struct ChatMessage: Identifiable, Equatable {
    let id: String
    var text: String
    let sender: Sender
    let timestamp: Date
    var isFinal: Bool
    var isDraft: Bool
    var type: MessageType
    
    enum Sender: Equatable {
        case user
        case model
    }
    
    enum MessageType: Equatable {
        case audio
        case text
    }
    
    init(id: String, text: String, sender: Sender, timestamp: Date = Date(), isFinal: Bool = false, isDraft: Bool = false, type: MessageType = .audio) {
        self.id = id
        self.text = text
        self.sender = sender
        self.timestamp = timestamp
        self.isFinal = isFinal
        self.isDraft = isDraft
        self.type = type
    }
}

