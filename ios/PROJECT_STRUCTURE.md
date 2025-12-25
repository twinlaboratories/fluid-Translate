# Project Structure

```
ios/
├── DuoTranslate/                    # Main app directory
│   ├── DuoTranslateApp.swift       # App entry point (@main)
│   ├── Models.swift                # Data models (Language, ChatMessage)
│   ├── GeminiService.swift         # Core service (WebSocket, Audio, Translation)
│   ├── Config.swift                # Configuration helper for API keys
│   ├── Info.plist                  # App configuration & permissions
│   └── Views/                      # SwiftUI views
│       ├── ContentView.swift       # Main split-screen view
│       ├── PersonView.swift        # Individual person's view (with saved phrases)
│       ├── MessageBubble.swift    # Message display component
│       └── AudioVisualizer.swift   # Audio level visualization
├── README.md                        # Comprehensive documentation
├── SETUP.md                        # Quick setup guide
└── PROJECT_STRUCTURE.md            # This file
```

## File Descriptions

### Core Files

**DuoTranslateApp.swift**
- App entry point using `@main` attribute
- Creates the main window with `ContentView`

**Models.swift**
- `Language`: Represents a supported language with voice mapping
- `ChatMessage`: Message structure with sender, text, and metadata
- `AVAILABLE_LANGUAGES`: Array of all supported languages

**GeminiService.swift**
- `ObservableObject` that manages the entire translation pipeline
- WebSocket connection to Gemini Live API
- Audio capture via AVAudioEngine
- Audio playback via AVAudioPlayerNode
- Real-time transcription handling
- Text translation via REST API
- Published properties for SwiftUI binding

**Config.swift**
- Centralized API key management
- Supports multiple storage methods (Keychain, UserDefaults, Environment)
- Easy to extend for production security

### Views

**ContentView.swift**
- Main container view
- Splits screen into two `PersonView` instances
- Manages connection state
- Displays errors in divider

**PersonView.swift**
- Individual person's interface
- Language selector
- Message list with auto-scroll
- Text input field
- Saved phrases modal
- Audio visualizer
- Supports 180° rotation for top person

**MessageBubble.swift**
- Individual message display
- Different styling for user vs model messages
- Shows message metadata (type, draft status)

**AudioVisualizer.swift**
- Animated bars showing audio level
- Uses spring animations for smooth transitions

### Configuration

**Info.plist**
- Microphone usage description (required for App Store)
- Supported interface orientations
- Launch screen configuration

## Architecture

### MVVM Pattern

- **Model**: `Language`, `ChatMessage` (in Models.swift)
- **View**: All SwiftUI views in Views/
- **ViewModel**: `GeminiService` (ObservableObject)

### Data Flow

1. **Audio Input**:
   - Microphone → AVAudioEngine → Converter (16kHz) → Base64 → WebSocket

2. **Audio Output**:
   - WebSocket → Base64 → PCM Buffer → AVAudioPlayerNode → Speakers

3. **Text Input**:
   - TextField → GeminiService.handleTextEntry() → REST API → Update messages

4. **Transcription**:
   - WebSocket messages → Parse JSON → Update ChatMessage → SwiftUI updates

### Threading

- Audio processing: Background queue (`audioQueue`)
- WebSocket: URLSession delegate queue
- UI updates: Main thread (via `@Published` and `DispatchQueue.main.async`)

## Dependencies

### System Frameworks
- `AVFoundation`: Audio capture and playback
- `Foundation`: Basic types and networking
- `SwiftUI`: User interface
- `Combine`: Reactive programming

### External Services
- Google Gemini Live API (WebSocket)
- Google Gemini REST API (for text translation)

## Key Features Implementation

### Real-time Audio Translation
- Uses Gemini Live API with WebSocket
- 16kHz PCM audio input
- 24kHz PCM audio output
- Low-latency audio pipeline

### Text Translation
- Debounced requests (1 second)
- Draft message support
- Final message handling
- Error handling for quota limits

### Saved Phrases
- Per-language storage in UserDefaults
- Quick access modal
- Add/delete functionality

### Liquid Glass UI
- SwiftUI Materials (`.ultraThinMaterial`, `.thinMaterial`)
- Blur effects
- Transparent backgrounds
- Smooth animations

## Extension Points

### Adding New Languages
1. Add to `AVAILABLE_LANGUAGES` in `Models.swift`
2. Ensure voice name is valid for Gemini API

### Customizing UI
- Modify SwiftUI views in `Views/` directory
- Adjust materials and colors
- Customize animations

### Enhancing Security
- Implement Keychain storage in `Config.swift`
- Add certificate pinning for WebSocket
- Encrypt sensitive data

### Performance Optimization
- Adjust audio buffer sizes
- Optimize message rendering
- Cache translations

