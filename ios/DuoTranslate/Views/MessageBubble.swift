import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.sender == .user { Spacer() }
            
            VStack(alignment: message.sender == .user ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(message.sender == .user ? .white : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Group {
                            if message.sender == .user {
                                Color.gray.opacity(0.3)
                            } else {
                                Color.blue.opacity(0.6)
                            }
                        }
                    )
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
                    .opacity(message.isDraft ? 0.8 : 1.0)
                
                HStack(spacing: 4) {
                    Text(message.sender == .user ? "Original" : "Translation")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    
                    if message.type == .text {
                        Text("• Text")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    
                    if message.isDraft {
                        Text("• Typing...")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
            }
            
            if message.sender == .model { Spacer() }
        }
    }
}

