//
//  InfoPill.swift
//  emoji-map
//
//  Created by Enrique on 3/6/25.
//

import SwiftUI

struct InfoPill: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 12))
            
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    VStack(spacing: 10) {
        InfoPill(icon: "dollarsign.circle.fill", text: "$$", color: .green)
        InfoPill(icon: "star.fill", text: "4.5 ★", color: .yellow)
        InfoPill(icon: "checkmark.circle.fill", text: "Open now", color: .green)
        InfoPill(icon: "xmark.circle.fill", text: "Closed", color: .red)
    }
    .padding()
} 