import React, { useState } from 'react';
import { LANGUAGES } from './types';
import { useLiveTranslator } from './hooks/useLiveTranslator';
import { PersonView } from './components/PersonView';

export default function App() {
  const [lang1, setLang1] = useState(LANGUAGES[0]); // Default: English
  const [lang2, setLang2] = useState(LANGUAGES[1]); // Default: Spanish
  
  const { 
    connect, 
    disconnect, 
    isConnected, 
    messages, 
    error,
    audioLevel,
    handleTextEntry
  } = useLiveTranslator({ lang1, lang2 });

  const [isConnecting, setIsConnecting] = useState(false);

  const handleToggle = async () => {
    if (isConnected) {
      await disconnect();
    } else {
      setIsConnecting(true);
      await connect();
      setIsConnecting(false);
    }
  };

  return (
    <div className="h-[100dvh] w-full bg-black flex flex-col overflow-hidden supports-[height:100dvh]:h-[100dvh]">
      
      {/* Top Person (Upside Down) */}
      <PersonView 
        isUpsideDown={true}
        selectedLang={lang2}
        onLangChange={setLang2}
        messages={messages} // Both see same messages stream
        isConnected={isConnected}
        isConnecting={isConnecting}
        onToggleConnection={handleToggle}
        audioLevel={audioLevel}
        onSendText={handleTextEntry}
        allowSavedPhrases={false}
      />

      {/* Divider / Action Center */}
      <div className="h-1 bg-gray-700 relative flex-none flex items-center justify-center z-50">
         {error && (
             <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-red-600 text-white px-4 py-1 rounded-full text-xs font-bold shadow-lg whitespace-nowrap">
                 {error}
             </div>
         )}
      </div>

      {/* Bottom Person (Normal) */}
      <PersonView 
        isUpsideDown={false}
        selectedLang={lang1}
        onLangChange={setLang1}
        messages={messages}
        isConnected={isConnected}
        isConnecting={isConnecting}
        onToggleConnection={handleToggle}
        audioLevel={audioLevel}
        onSendText={handleTextEntry}
        allowSavedPhrases={true}
      />
    </div>
  );
}