import { useEffect, useRef, useState, useCallback } from 'react';
import { GoogleGenAI, LiveServerMessage, Modality } from '@google/genai';
import { createBlob, decode, decodeAudioData } from '../utils/audio';
import { ChatMessage, Language } from '../types';

interface UseLiveTranslatorProps {
  lang1: Language;
  lang2: Language;
}

type DraftSession = {
    userId: string;
    modelId: string;
    timeoutId: ReturnType<typeof setTimeout> | null;
    abortController: AbortController | null;
};

export const useLiveTranslator = ({ lang1, lang2 }: UseLiveTranslatorProps) => {
  const [isConnected, setIsConnected] = useState(false);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [audioLevel, setAudioLevel] = useState(0);

  // Refs for audio handling to avoid re-renders
  const inputAudioContextRef = useRef<AudioContext | null>(null);
  const outputAudioContextRef = useRef<AudioContext | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const processorRef = useRef<ScriptProcessorNode | null>(null);
  const sourceRef = useRef<MediaStreamAudioSourceNode | null>(null);
  const sessionPromiseRef = useRef<Promise<any> | null>(null);
  const nextStartTimeRef = useRef<number>(0);
  const sourcesRef = useRef<Set<AudioBufferSourceNode>>(new Set());

  // Transcription state refs
  const currentInputTranscriptionRef = useRef('');
  const currentOutputTranscriptionRef = useRef('');
  const currentUserIdRef = useRef<string | null>(null);
  const currentModelIdRef = useRef<string | null>(null);

  // Drafts for typing: Map language code to current draft session
  const draftsRef = useRef<Record<string, DraftSession>>({});

  const handleTextEntry = async (text: string, srcLang: Language, isFinal: boolean) => {
    const draftKey = srcLang.code;
    const tgtLang = srcLang.code === lang1.code ? lang2 : lang1;
    
    // 1. Initialize draft session if needed
    if (!draftsRef.current[draftKey]) {
        const idBase = Date.now().toString() + Math.random().toString().slice(2, 6);
        draftsRef.current[draftKey] = {
            userId: idBase + '-user',
            modelId: idBase + '-model',
            timeoutId: null,
            abortController: null
        };
    }
    
    const session = draftsRef.current[draftKey];

    // 2. Handle Empty Text (Deletion)
    if (!text.trim()) {
        // Remove messages if they exist
        setMessages(prev => prev.filter(m => m.id !== session.userId && m.id !== session.modelId));
        if (session.timeoutId) clearTimeout(session.timeoutId);
        if (session.abortController) session.abortController.abort();
        delete draftsRef.current[draftKey];
        return;
    }

    // 3. Update User Message Immediately
    setMessages(prev => {
        const exists = prev.some(m => m.id === session.userId);
        const userMsg: ChatMessage = {
            id: session.userId,
            text: text,
            sender: 'user',
            timestamp: Date.now(),
            isFinal: isFinal,
            isDraft: !isFinal,
            type: 'text'
        };

        const modelMsg: ChatMessage = {
            id: session.modelId,
            text: exists ? prev.find(m => m.id === session.modelId)?.text || '...' : '...',
            sender: 'model',
            timestamp: Date.now(),
            isFinal: isFinal,
            isDraft: !isFinal,
            type: 'text'
        };

        if (exists) {
            return prev.map(m => {
                if (m.id === session.userId) return userMsg;
                if (m.id === session.modelId && isFinal) return modelMsg; // Only force update model on final if needed
                return m;
            });
        } else {
            return [...prev, userMsg, modelMsg];
        }
    });

    // 4. Handle Finalization
    if (isFinal) {
        if (session.timeoutId) clearTimeout(session.timeoutId);
        if (session.abortController) session.abortController.abort();
        // Ensure final translation is clean (trigger one last immediate translation if needed, or assume last stream caught it)
        // For simplicity, we trigger one final high-priority translation to ensure accuracy
        performTranslation(text, srcLang, tgtLang, session, true);
        delete draftsRef.current[draftKey];
        return;
    }

    // 5. Debounced Translation
    if (session.timeoutId) clearTimeout(session.timeoutId);
    
    // Increased debounce to 1000ms to prevent 429 Quota Exceeded errors
    session.timeoutId = setTimeout(() => {
        performTranslation(text, srcLang, tgtLang, session, false);
    }, 1000); 
  };

  const performTranslation = async (text: string, src: Language, tgt: Language, session: DraftSession, isFinal: boolean) => {
      // Abort previous request for this session
      if (session.abortController) session.abortController.abort();
      session.abortController = new AbortController();

      try {
        const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
        const response = await ai.models.generateContent({
            model: 'gemini-3-flash-preview',
            contents: `Translate to ${tgt.name}. Only output the translation. Text: ${text}`,
        });
        
        // If we were aborted, don't update
        if (session.abortController.signal.aborted) return;

        const translatedText = response.text || '';
        
        setMessages(prev => prev.map(m => {
            if (m.id === session.modelId) {
                return {
                    ...m,
                    text: translatedText,
                    isFinal: isFinal,
                    isDraft: !isFinal
                };
            }
            return m;
        }));
        
        // Clear error if successful
        setError(null);

      } catch (e: any) {
          if (!e.message?.includes('aborted')) {
              console.error("Translation error", e);
              if (e.message?.includes('429') || e.status === 429) {
                  setError("Quota exceeded. Please wait a moment.");
              }
          }
      }
  };

  const disconnect = useCallback(async () => {
    if (processorRef.current) {
      processorRef.current.disconnect();
      processorRef.current = null;
    }
    if (sourceRef.current) {
      sourceRef.current.disconnect();
      sourceRef.current = null;
    }
    if (streamRef.current) {
      streamRef.current.getTracks().forEach(track => track.stop());
      streamRef.current = null;
    }
    if (inputAudioContextRef.current) {
      await inputAudioContextRef.current.close();
      inputAudioContextRef.current = null;
    }
    if (outputAudioContextRef.current) {
      // Stop all playing sources
      sourcesRef.current.forEach(source => source.stop());
      sourcesRef.current.clear();
      await outputAudioContextRef.current.close();
      outputAudioContextRef.current = null;
    }
    
    // Close session if possible (wrapper logic mostly)
    sessionPromiseRef.current = null;
    
    // Reset streaming refs
    currentInputTranscriptionRef.current = '';
    currentOutputTranscriptionRef.current = '';
    currentUserIdRef.current = null;
    currentModelIdRef.current = null;
    
    setIsConnected(false);
    setAudioLevel(0);
  }, []);

  const connect = useCallback(async () => {
    try {
      setError(null);
      
      // Initialize Audio Contexts
      inputAudioContextRef.current = new (window.AudioContext || (window as any).webkitAudioContext)({ sampleRate: 16000 });
      outputAudioContextRef.current = new (window.AudioContext || (window as any).webkitAudioContext)({ sampleRate: 24000 });
      
      // Resume contexts to ensure they are active (especially after user gesture)
      await inputAudioContextRef.current.resume();
      await outputAudioContextRef.current.resume();
      
      const outputNode = outputAudioContextRef.current.createGain();
      outputNode.connect(outputAudioContextRef.current.destination);

      // Get Mic Stream
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      streamRef.current = stream;

      const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
      
      const config = {
        responseModalities: [Modality.AUDIO],
        speechConfig: {
          voiceConfig: { prebuiltVoiceConfig: { voiceName: 'Kore' } },
        },
        systemInstruction: `You are a real-time interpreter. Translate spoken audio between ${lang1.name} and ${lang2.name}. 
        Rules:
        1. When you hear ${lang1.name}, translate to ${lang2.name}.
        2. When you hear ${lang2.name}, translate to ${lang1.name}.
        3. Speak the translation immediately.
        4. Speak quickly and efficiently. Increase your speaking rate slightly to be faster than normal conversation.
        5. Keep translations short and direct.
        6. Do not answer questions or engage in conversation, ONLY TRANSLATE.
        7. If audio is unintelligible, stay silent.`,
        inputAudioTranscription: {},
        outputAudioTranscription: {},
      };

      const sessionPromise = ai.live.connect({
        model: 'gemini-2.5-flash-native-audio-preview-09-2025',
        config,
        callbacks: {
          onopen: () => {
            setIsConnected(true);
            
            // Setup Input Processing
            if (!inputAudioContextRef.current || !streamRef.current) return;
            
            const source = inputAudioContextRef.current.createMediaStreamSource(streamRef.current);
            const processor = inputAudioContextRef.current.createScriptProcessor(4096, 1, 1);
            
            processor.onaudioprocess = (e) => {
              const inputData = e.inputBuffer.getChannelData(0);
              
              // Simple volume meter
              let sum = 0;
              for(let i=0; i<inputData.length; i++) sum += inputData[i] * inputData[i];
              const rms = Math.sqrt(sum / inputData.length);
              setAudioLevel(rms);

              const pcmBlob = createBlob(inputData);
              sessionPromise.then(session => {
                session.sendRealtimeInput({ media: pcmBlob });
              });
            };

            source.connect(processor);
            processor.connect(inputAudioContextRef.current.destination);
            
            sourceRef.current = source;
            processorRef.current = processor;
          },
          onmessage: async (message: LiveServerMessage) => {
            const serverContent = message.serverContent;

            // 1. User Input Transcription (Real-time Streaming)
            if (serverContent?.inputTranscription) {
              const text = serverContent.inputTranscription.text;
              if (text) {
                 currentInputTranscriptionRef.current += text;
                 
                 setMessages(prev => {
                     const currentId = currentUserIdRef.current;
                     const fullText = currentInputTranscriptionRef.current;

                     if (currentId) {
                         // Update existing streaming message
                         return prev.map(m => m.id === currentId ? { ...m, text: fullText } : m);
                     } else {
                         // Start new user message
                         const newId = Date.now().toString() + '-user-audio';
                         currentUserIdRef.current = newId;
                         return [...prev, {
                             id: newId,
                             text: fullText,
                             sender: 'user',
                             timestamp: Date.now(),
                             isFinal: false,
                             isDraft: true,
                             type: 'audio'
                         }];
                     }
                 });
              }
            }
            
            // 2. Model Output Transcription (Real-time Streaming)
            if (serverContent?.outputTranscription) {
               const text = serverContent.outputTranscription.text;
               if (text) {
                   currentOutputTranscriptionRef.current += text;

                   setMessages(prev => {
                     const currentId = currentModelIdRef.current;
                     const fullText = currentOutputTranscriptionRef.current;

                     if (currentId) {
                         return prev.map(m => m.id === currentId ? { ...m, text: fullText } : m);
                     } else {
                         const newId = Date.now().toString() + '-model-audio';
                         currentModelIdRef.current = newId;
                         return [...prev, {
                             id: newId,
                             text: fullText,
                             sender: 'model',
                             timestamp: Date.now(),
                             isFinal: false,
                             isDraft: true,
                             type: 'audio'
                         }];
                     }
                 });
               }
            }

            // 3. Turn Complete - Finalize the current streaming messages
            if (serverContent?.turnComplete) {
               setMessages(prev => prev.map(m => {
                   if ((currentUserIdRef.current && m.id === currentUserIdRef.current) || 
                       (currentModelIdRef.current && m.id === currentModelIdRef.current)) {
                       return { ...m, isFinal: true, isDraft: false };
                   }
                   return m;
               }));

               // Reset accumulators and IDs for next turn
               currentInputTranscriptionRef.current = '';
               currentOutputTranscriptionRef.current = '';
               currentUserIdRef.current = null;
               currentModelIdRef.current = null;
            }

            // Handle Audio Output
            const base64Audio = message.serverContent?.modelTurn?.parts?.[0]?.inlineData?.data;
            if (base64Audio && outputAudioContextRef.current) {
              const ctx = outputAudioContextRef.current;
              nextStartTimeRef.current = Math.max(nextStartTimeRef.current, ctx.currentTime);
              
              const audioBuffer = await decodeAudioData(
                decode(base64Audio),
                ctx,
                24000,
                1
              );
              
              const source = ctx.createBufferSource();
              source.buffer = audioBuffer;
              source.connect(outputNode);
              
              source.addEventListener('ended', () => {
                sourcesRef.current.delete(source);
              });
              
              source.start(nextStartTimeRef.current);
              nextStartTimeRef.current += audioBuffer.duration;
              sourcesRef.current.add(source);
            }
          },
          onclose: () => {
            setIsConnected(false);
          },
          onerror: (err) => {
            console.error("Gemini Live Error:", err);
            setError("Connection error");
            setIsConnected(false);
          }
        }
      });
      
      sessionPromiseRef.current = sessionPromise;

    } catch (err: any) {
      console.error(err);
      setError(err.message || "Failed to start translator");
      setIsConnected(false);
    }
  }, [lang1, lang2]);

  return {
    connect,
    disconnect,
    isConnected,
    messages,
    error,
    audioLevel,
    handleTextEntry
  };
};