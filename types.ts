export interface ChatMessage {
  id: string;
  text: string;
  sender: 'user' | 'model'; // 'user' is the speaker, 'model' is the translation
  timestamp: number;
  isFinal: boolean;
  type?: 'audio' | 'text';
  isDraft?: boolean; // True while the user is actively typing
}

export interface Language {
  code: string;
  name: string;
  voiceName: string; // Gemini voice mapping
}

export const LANGUAGES: Language[] = [
  { code: 'en-US', name: 'English', voiceName: 'Puck' },
  { code: 'es-ES', name: 'Spanish', voiceName: 'Kore' },
  { code: 'fr-FR', name: 'French', voiceName: 'Charon' },
  { code: 'de-DE', name: 'German', voiceName: 'Fenrir' },
  { code: 'ja-JP', name: 'Japanese', voiceName: 'Zephyr' },
  { code: 'ko-KR', name: 'Korean', voiceName: 'Puck' },
  { code: 'zh-CN', name: 'Chinese (Mandarin)', voiceName: 'Kore' },
  { code: 'ur-PK', name: 'Urdu', voiceName: 'Charon' },
  { code: 'pa-IN', name: 'Punjabi', voiceName: 'Fenrir' },
];

export interface TranslatorState {
  isActive: boolean;
  isConnecting: boolean;
  error: string | null;
}