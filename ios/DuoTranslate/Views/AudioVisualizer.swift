import SwiftUI

struct AudioVisualizer: View {
    var level: Float // 0 to 1
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 4, height: height(for: index))
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: level)
            }
        }
    }
    
    private func height(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 8
        let variance = CGFloat((index % 3) + 1) * 5
        let dynamicHeight = baseHeight + (CGFloat(level) * variance)
        return max(baseHeight, min(dynamicHeight, 32))
    }
}

