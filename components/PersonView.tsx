import React, { useEffect, useRef, useState } from 'react';
import { ChatMessage, Language, LANGUAGES } from '../types';
import { AudioVisualizer } from './AudioVisualizer';

interface PersonViewProps {
  isUpsideDown?: boolean;
  selectedLang: Language;
  onLangChange: (lang: Language) => void;
  messages: ChatMessage[];
  isConnected: boolean;
  isConnecting: boolean;
  onToggleConnection: () => void;
  audioLevel: number;
  onSendText?: (text: string, lang: Language, isFinal: boolean) => void;
  allowSavedPhrases?: boolean;
}

export const PersonView: React.FC<PersonViewProps> = ({
  isUpsideDown = false,
  selectedLang,
  onLangChange,
  messages,
  isConnected,
  isConnecting,
  onToggleConnection,
  audioLevel,
  onSendText,
  allowSavedPhrases = true
}) => {
  const scrollRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const [inputText, setInputText] = useState('');
  
  // Saved Phrases State
  const [showPhrases, setShowPhrases] = useState(false);
  const [phrases, setPhrases] = useState<string[]>([]);
  const [newPhrase, setNewPhrase] = useState('');

  // Auto-scroll to latest message
  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [messages]);

  // Load phrases for selected language
  useEffect(() => {
    const key = `phrases-${selectedLang.code}`;
    try {
        const saved = localStorage.getItem(key);
        if (saved) {
            setPhrases(JSON.parse(saved));
        } else {
            // Default phrases if none exist
            setPhrases(["Hello", "Thank you", "Yes", "No", "I don't understand", "Please"]);
        }
    } catch (e) {
        console.error("Failed to load phrases", e);
    }
  }, [selectedLang.code]);

  const handleAddPhrase = (e: React.FormEvent) => {
      e.preventDefault();
      if (!newPhrase.trim()) return;
      const updated = [...phrases, newPhrase.trim()];
      setPhrases(updated);
      localStorage.setItem(`phrases-${selectedLang.code}`, JSON.stringify(updated));
      setNewPhrase('');
  };

  const handleDeletePhrase = (index: number, e: React.MouseEvent) => {
      e.stopPropagation();
      const updated = phrases.filter((_, i) => i !== index);
      setPhrases(updated);
      localStorage.setItem(`phrases-${selectedLang.code}`, JSON.stringify(updated));
  };

  const handlePhraseClick = (text: string) => {
      if (onSendText) {
          onSendText(text, selectedLang, true);
          setShowPhrases(false);
      }
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
      const newValue = e.target.value;
      setInputText(newValue);
      if (onSendText) {
          onSendText(newValue, selectedLang, false); // Not final
      }
  };

  const handleFinalize = () => {
    if (inputText.trim() && onSendText) {
      onSendText(inputText, selectedLang, true); // Finalize
      setInputText('');
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleFinalize();
      // Keep focus on input for rapid back-and-forth typing
      inputRef.current?.focus();
    }
  };

  const handleInputFocus = () => {
    // Small delay to allow keyboard to appear before scrolling
    setTimeout(() => {
      inputRef.current?.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
      if (scrollRef.current) {
        scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
      }
    }, 100);
  };

  return (
    <div 
      className={`flex-1 flex flex-col bg-gray-900 relative border-b-2 border-gray-800 min-h-0 ${isUpsideDown ? 'rotate-180' : ''}`}
    >
      {/* Header / Controls */}
      <div className="flex-none p-3 md:p-4 flex items-center justify-between bg-gray-950/50 backdrop-blur-sm z-20 relative">
        <div className="flex items-center gap-2">
            <select 
              value={selectedLang.code}
              onChange={(e) => {
                 const l = LANGUAGES.find(lang => lang.code === e.target.value);
                 if (l) onLangChange(l);
              }}
              disabled={isConnected}
              className="bg-gray-800 text-white px-3 py-2 rounded-xl text-base md:text-lg font-medium outline-none border border-gray-700 focus:border-blue-500 disabled:opacity-50"
            >
              {LANGUAGES.map(l => (
                <option key={l.code} value={l.code}>{l.name}</option>
              ))}
            </select>
            
            {allowSavedPhrases && (
            <button 
                onClick={() => setShowPhrases(!showPhrases)}
                className="p-2 bg-gray-800 hover:bg-gray-700 text-gray-300 rounded-xl border border-gray-700 transition-colors"
                title="Saved Phrases"
            >
                <svg className="w-5 h-5 md:w-6 md:h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z" />
                </svg>
            </button>
            )}
        </div>

        <div className="flex items-center gap-2 md:gap-3">
            {isConnected && (
                <div className="flex items-center gap-2 text-green-400 text-xs md:text-sm font-bold animate-pulse">
                    <div className="w-1.5 h-1.5 md:w-2 md:h-2 bg-green-500 rounded-full"></div>
                    LIVE
                </div>
            )}
            
            <button
                onClick={onToggleConnection}
                disabled={isConnecting}
                className={`w-10 h-10 md:w-12 md:h-12 rounded-full flex items-center justify-center transition-all ${
                    isConnected 
                    ? 'bg-red-500 hover:bg-red-600 text-white shadow-[0_0_15px_rgba(239,68,68,0.5)]' 
                    : 'bg-blue-600 hover:bg-blue-500 text-white shadow-[0_0_15px_rgba(37,99,235,0.5)]'
                }`}
            >
                {isConnected ? (
                    <svg className="w-5 h-5 md:w-6 md:h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" /></svg>
                ) : (
                    <svg className="w-5 h-5 md:w-6 md:h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" /></svg>
                )}
            </button>
        </div>
      </div>

      {/* Saved Phrases Modal Overlay */}
      {showPhrases && (
          <div className="absolute inset-0 z-30 bg-gray-950/90 backdrop-blur-md flex flex-col animate-in fade-in duration-200">
              <div className="flex items-center justify-between p-4 border-b border-gray-800">
                  <h3 className="text-lg font-bold text-white">Saved Phrases ({selectedLang.name})</h3>
                  <button onClick={() => setShowPhrases(false)} className="p-2 text-gray-400 hover:text-white">
                      <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                      </svg>
                  </button>
              </div>
              <div className="flex-1 overflow-y-auto p-4 space-y-2 no-scrollbar">
                  {phrases.map((phrase, idx) => (
                      <div 
                        key={idx} 
                        onClick={() => handlePhraseClick(phrase)}
                        className="flex items-center justify-between bg-gray-800 hover:bg-gray-700 p-3 rounded-xl cursor-pointer group transition-colors border border-gray-700 hover:border-blue-500/50"
                      >
                          <span className="text-gray-200 text-lg">{phrase}</span>
                          <button 
                            onClick={(e) => handleDeletePhrase(idx, e)}
                            className="p-2 text-gray-500 hover:text-red-400 opacity-0 group-hover:opacity-100 transition-opacity"
                          >
                              <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                              </svg>
                          </button>
                      </div>
                  ))}
              </div>
              <form onSubmit={handleAddPhrase} className="p-4 border-t border-gray-800 bg-gray-900 flex gap-2">
                  <input 
                      type="text" 
                      value={newPhrase}
                      onChange={(e) => setNewPhrase(e.target.value)}
                      placeholder="Add new phrase..."
                      className="flex-1 bg-gray-800 text-white px-4 py-3 rounded-xl outline-none focus:ring-2 focus:ring-blue-500 placeholder-gray-500"
                  />
                  <button 
                      type="submit"
                      disabled={!newPhrase.trim()}
                      className="p-3 bg-blue-600 rounded-xl text-white disabled:opacity-50 hover:bg-blue-500 transition-colors"
                  >
                      <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                      </svg>
                  </button>
              </form>
          </div>
      )}

      {/* Conversation Area */}
      <div 
        ref={scrollRef}
        className="flex-1 overflow-y-auto p-4 md:p-6 space-y-4 md:space-y-6 no-scrollbar scroll-smooth relative"
      >
        {messages.length === 0 && (
          <div className="h-full flex items-center justify-center text-gray-500 text-center px-4">
             <p className="text-sm md:text-base">Tap mic to speak or type below to interpret.</p>
          </div>
        )}
        
        {messages.map((msg) => (
            <div 
                key={msg.id} 
                className={`flex flex-col ${msg.sender === 'user' ? 'items-end' : 'items-start'} ${msg.isDraft ? 'opacity-80' : 'opacity-100'}`}
            >
                <div className={`
                    max-w-[90%] p-3 md:p-4 rounded-2xl text-lg md:text-xl leading-relaxed transition-all break-words
                    ${msg.sender === 'user' 
                        ? 'bg-gray-800 text-gray-300 rounded-tr-sm' 
                        : 'bg-blue-600 text-white font-medium rounded-tl-sm shadow-lg'}
                `}>
                    {msg.text}
                </div>
                <span className="text-[10px] md:text-xs text-gray-500 mt-1 px-1">
                    {msg.sender === 'user' ? 'Original' : 'Translation'}
                    {msg.type === 'text' && ' • Text'}
                    {msg.isDraft && ' • Typing...'}
                </span>
            </div>
        ))}
        
        {/* Active Audio Indicator */}
        {isConnected && (
            <div className="sticky bottom-0 left-0 right-0 flex justify-center pb-2 pt-8 bg-gradient-to-t from-gray-900 to-transparent pointer-events-none">
                <AudioVisualizer isActive={audioLevel > 0.01} color="bg-blue-400" />
            </div>
        )}
      </div>

      {/* Input Area */}
      <div className="flex-none p-3 bg-gray-950/90 backdrop-blur border-t border-gray-800 flex items-center gap-2">
        <input 
            ref={inputRef}
            type="text" 
            value={inputText}
            onChange={handleInputChange}
            onKeyDown={handleKeyDown}
            onFocus={handleInputFocus}
            enterKeyHint="send"
            placeholder={`Type in ${selectedLang.name}...`}
            className="flex-1 bg-gray-800 text-white px-4 py-3 rounded-xl outline-none focus:ring-2 focus:ring-blue-500 placeholder-gray-500 text-base"
        />
        <button 
            onClick={handleFinalize}
            disabled={!inputText.trim()}
            className="p-3 bg-blue-600 rounded-xl text-white disabled:opacity-50 disabled:cursor-not-allowed hover:bg-blue-500 transition-colors flex-none"
        >
            <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
            </svg>
        </button>
      </div>
    </div>
  );
};