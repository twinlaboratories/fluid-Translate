# Quick Setup Guide

## Step-by-Step Xcode Project Creation

### 1. Create New Project

1. Open **Xcode**
2. File → New → Project (or ⌘⇧N)
3. Select **iOS** → **App**
4. Click **Next**
5. Fill in:
   - **Product Name**: `DuoTranslate`
   - **Team**: Select your Apple Developer team
   - **Organization Identifier**: `com.yourcompany` (or your domain)
   - **Bundle Identifier**: Will auto-fill as `com.yourcompany.DuoTranslate`
   - **Interface**: **SwiftUI**
   - **Language**: **Swift**
   - **Storage**: **None**
   - **Include Tests**: Optional
6. Click **Next**
7. Choose a location and click **Create**

### 2. Delete Default Files

1. In Xcode, delete `ContentView.swift` (we have our own)
2. Keep `DuoTranslateApp.swift` but we'll replace it

### 3. Add All Source Files

**Method 1: Drag and Drop**
1. Open Finder and navigate to `ios/DuoTranslate/`
2. Select all `.swift` files and `Info.plist`
3. Drag them into Xcode's Project Navigator (left sidebar)
4. In the dialog:
   - ✅ Check "Copy items if needed"
   - ✅ Select "Create groups" (not folder references)
   - ✅ Ensure "DuoTranslate" target is checked
   - Click **Finish**

**Method 2: Add Files Menu**
1. Right-click on the project folder in Xcode
2. Select "Add Files to DuoTranslate..."
3. Navigate to `ios/DuoTranslate/`
4. Select all files
5. Follow the same options as Method 1

### 4. Replace App Entry Point

1. Open `DuoTranslateApp.swift` (the one Xcode created)
2. Replace its contents with the content from `ios/DuoTranslate/DuoTranslateApp.swift`

### 5. Configure Info.plist

1. In Xcode, select your project in the navigator
2. Select the "DuoTranslate" target
3. Go to the **Info** tab
4. Verify that "Privacy - Microphone Usage Description" appears with the text:
   > "This app needs access to the microphone to listen to your speech for real-time translation."

If it doesn't appear:
1. Click the **+** button
2. Type "Privacy - Microphone Usage Description" (it will autocomplete)
3. Set the value to the description above

### 6. Set Deployment Target

1. Select your project → Target "DuoTranslate"
2. Go to **General** tab
3. Set **iOS Deployment Target** to **17.0** or later

### 7. Configure API Key

**Option A: Environment Variable (Recommended for Development)**

1. In Xcode: Product → Scheme → Edit Scheme (or ⌘<)
2. Select **Run** → **Arguments**
3. Under "Environment Variables", click **+**
4. Add:
   - Name: `GEMINI_API_KEY`
   - Value: Your actual API key

**Option B: UserDefaults (Quick Testing)**

Add this code temporarily in `DuoTranslateApp.swift`:

```swift
@main
struct DuoTranslateApp: App {
    init() {
        // Set your API key here for testing (remove before App Store submission)
        AppConfig.setAPIKey("YOUR_API_KEY_HERE")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**Option C: Keychain (Production)**

Implement Keychain storage in `Config.swift` (see comments in that file).

### 8. Build and Run

1. Connect an iOS device (microphone requires real device)
2. Select your device from the device menu
3. Press ⌘R to build and run

## Troubleshooting

### "No such module" errors
- Clean build folder: Product → Clean Build Folder (⌘⇧K)
- Build again: ⌘B

### Files not found
- Ensure all files are added to the target:
  - Select file in navigator
  - Check "Target Membership" in File Inspector (right panel)
  - Ensure "DuoTranslate" is checked

### Microphone permission not requested
- Verify Info.plist has `NSMicrophoneUsageDescription`
- Delete app from device and reinstall
- Check Settings → Privacy → Microphone

### API Key not working
- Verify the key is set correctly
- Check console for error messages
- Ensure key has proper permissions in Google Cloud Console

## Next Steps

1. Test on a real device
2. Customize bundle identifier for your organization
3. Add app icon and launch screen
4. Implement Keychain storage for API key (production)
5. Prepare for App Store submission (see main README.md)

