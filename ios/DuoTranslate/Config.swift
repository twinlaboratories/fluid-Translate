import Foundation

/// Configuration helper for API keys and app settings
/// 
/// For production, implement secure storage using Keychain Services
struct AppConfig {
    /// Get Gemini API key from secure storage
    /// 
    /// Implementation priority:
    /// 1. Keychain (most secure - implement for production)
    /// 2. Environment variable (development)
    /// 3. UserDefaults (testing only - not secure)
    static var geminiAPIKey: String {
        // TODO: Implement Keychain storage for production
        // Example:
        // if let key = KeychainHelper.shared.get(key: "gemini_api_key") {
        //     return key
        // }
        
        // Fallback to environment variable
        if let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !key.isEmpty {
            return key
        }
        
        // Fallback to UserDefaults (for testing)
        if let key = UserDefaults.standard.string(forKey: "GEMINI_API_KEY"), !key.isEmpty {
            return key
        }
        
        return ""
    }
    
    /// Set API key (for testing/development)
    /// In production, use Keychain instead
    static func setAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "GEMINI_API_KEY")
    }
}

