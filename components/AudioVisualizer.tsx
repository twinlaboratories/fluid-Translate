import React from 'react';

interface AudioVisualizerProps {
  isActive: boolean;
  color: string;
}

export const AudioVisualizer: React.FC<AudioVisualizerProps> = ({ isActive, color }) => {
  return (
    <div className="flex items-center justify-center gap-1 h-8">
      {[1, 2, 3, 4, 5].map((i) => (
        <div
          key={i}
          className={`w-1.5 rounded-full transition-all duration-150 ${color}`}
          style={{
            height: isActive ? `${Math.random() * 24 + 8}px` : '4px',
            opacity: isActive ? 1 : 0.3,
            animation: isActive ? `pulse 0.5s infinite alternate -${i * 0.1}s` : 'none'
          }}
        />
      ))}
      <style>{`
        @keyframes pulse {
          0% { height: 8px; }
          100% { height: 32px; }
        }
      `}</style>
    </div>
  );
};