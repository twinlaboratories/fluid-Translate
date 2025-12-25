# DuoTranslate iOS App

Native iOS implementation of DuoTranslate using SwiftUI and AVFoundation. This app provides real-time speech-to-speech translation using Google's Gemini Live API.

## Features

- ✅ Real-time speech-to-speech translation
- ✅ Text input with live translation
- ✅ Saved phrases per language
- ✅ Liquid Glass UI design with SwiftUI Materials
- ✅ Split-screen interface with 180° rotation
- ✅ Audio visualizer
- ✅ Low-latency audio processing with AVFoundation

## Prerequisites

- Xcode 15.0 or later
- iOS 17.0+ deployment target
- Apple Developer account (for App Store submission)
- Gemini API key

## Setup Instructions

### 1. Create Xcode Project

1. Open Xcode
2. Create a new project:
   - Choose **iOS** → **App**
   - Product Name: `DuoTranslate`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **None** (we'll add files manually)

### 2. Add Source Files

Copy all files from this directory into your Xcode project:

```
DuoTranslate/
├── DuoTranslateApp.swift      (App entry point)
├── Models.swift               (Data models)
├── GeminiService.swift        (Core service)
├── Info.plist                 (App configuration)
└── Views/
    ├── ContentView.swift
    ├── PersonView.swift
    ├── MessageBubble.swift
    └── AudioVisualizer.swift
```

**In Xcode:**
1. Right-click on your project in the navigator
2. Select "Add Files to DuoTranslate..."
3. Select all the Swift files and Info.plist
4. Make sure "Copy items if needed" is checked
5. Ensure your app target is selected

### 3. Configure Info.plist

The `Info.plist` file is already configured with:
- Microphone usage description (required for App Store)
- Supported orientations

**Important:** Make sure the Info.plist is properly linked in your project:
1. Select your project in Xcode
2. Go to the target's "Info" tab
3. Verify the microphone permission description appears

### 4. Set API Key

You have two options for the API key:

#### Option A: Environment Variable (Development)
1. In Xcode, go to Product → Scheme → Edit Scheme
2. Select "Run" → "Arguments"
3. Add environment variable:
   - Name: `GEMINI_API_KEY`
   - Value: Your Gemini API key

#### Option B: Secure Storage (Production)
For App Store submission, implement secure key storage:

1. Add your API key to Keychain or a secure configuration file
2. Update `GeminiService.swift` to read from secure storage:

```swift
private var apiKey: String {
    // Implement your secure storage method
    if let key = KeychainHelper.shared.get(key: "gemini_api_key") {
        return key
    }
    return ""
}
```

### 5. Configure Build Settings

1. Select your project in Xcode
2. Go to "Build Settings"
3. Set **iOS Deployment Target** to **17.0** or later
4. Ensure **Swift Language Version** is set to **Swift 5**

### 6. Add Required Frameworks

The following frameworks are automatically linked, but verify in "Build Phases" → "Link Binary With Libraries":
- `AVFoundation.framework`
- `Foundation.framework`
- `SwiftUI.framework`
- `Combine.framework`

### 7. Configure App Capabilities

1. Select your project → Target → "Signing & Capabilities"
2. No additional capabilities needed (microphone access is handled via Info.plist)

## Building and Running

1. Connect an iOS device or use the Simulator (note: microphone access requires a real device)
2. Select your target device
3. Press ⌘R to build and run

## App Store Submission Checklist

### Privacy Requirements

1. **Privacy Policy**: You must have a privacy policy URL that explains:
   - Audio data is sent to Google Gemini API
   - How data is used and stored
   - User rights regarding their data

2. **App Privacy Details** (in App Store Connect):
   - **Data Types Collected**: Audio Data
   - **Data Linked to User**: Yes (if you track users)
   - **Data Used to Track**: No (unless you use analytics)
   - **Data Shared with Third Parties**: Yes (Google Gemini API)
   - **Purpose**: App Functionality

3. **Info.plist Privacy Descriptions**:
   - ✅ `NSMicrophoneUsageDescription` is already configured

### App Store Metadata

Prepare the following:
- App name: DuoTranslate
- Subtitle: Real-time speech translation
- Description: Highlight real-time translation, privacy, and ease of use
- Keywords: translation, speech, real-time, interpreter, language
- Screenshots: Capture the split-screen interface
- App icon: 1024x1024px

### Testing

Before submission, test:
- [ ] Microphone permission flow
- [ ] Real-time audio translation
- [ ] Text input translation
- [ ] Saved phrases functionality
- [ ] Language switching
- [ ] Connection/disconnection
- [ ] Error handling
- [ ] Background/foreground transitions
- [ ] Different device sizes (iPhone SE, iPhone Pro Max, iPad)

### Build for App Store

1. Select "Any iOS Device" as the destination
2. Product → Archive
3. Once archived, click "Distribute App"
4. Choose "App Store Connect"
5. Follow the upload process

## Architecture

### MVVM Pattern

- **Model**: `Language`, `ChatMessage` (in `Models.swift`)
- **View**: SwiftUI views (`ContentView`, `PersonView`, etc.)
- **ViewModel**: `GeminiService` (ObservableObject)

### Key Components

1. **GeminiService**: 
   - Manages WebSocket connection to Gemini Live API
   - Handles audio capture and playback via AVFoundation
   - Processes real-time transcriptions
   - Manages text translations

2. **Audio Pipeline**:
   - Input: Microphone → AVAudioEngine → 16kHz PCM → Base64 → WebSocket
   - Output: WebSocket → Base64 → 24kHz PCM → AVAudioPlayerNode → Speakers

3. **UI Components**:
   - Split-screen layout with rotation
   - Material-based "Liquid Glass" design
   - Real-time message streaming
   - Audio visualizer

## Troubleshooting

### Microphone Not Working
- Ensure Info.plist has `NSMicrophoneUsageDescription`
- Check that permission was granted in Settings
- Test on a real device (Simulator has limited audio support)

### WebSocket Connection Fails
- Verify API key is set correctly
- Check network connectivity
- Review error messages in console

### Audio Playback Issues
- Ensure audio session is configured correctly
- Check that AVAudioEngine is started
- Verify audio format conversion

### Build Errors
- Ensure all Swift files are added to the target
- Check that iOS deployment target is 17.0+
- Verify all frameworks are linked

## Performance Optimizations

- Audio processing runs on background queues
- UI updates are dispatched to main thread
- Audio buffers are efficiently converted
- WebSocket messages are processed asynchronously

## License

Same as the main project.

