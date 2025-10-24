//
//  LiquidGlassStyle.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 10/11/25.
//

import SwiftUI

struct LiquidGlassStyle {
    static let cornerRadius: CGFloat = 20
    static let shadowRadius: CGFloat = 10
    static let blurRadius: CGFloat = 20
    
    static var glassMaterial: Material {
        .ultraThinMaterial
    }
    
    static var cardBackground: some ShapeStyle {
        .ultraThinMaterial
    }
}

extension View {
    func liquidGlassCard() -> some View {
        self
            .background(LiquidGlassStyle.cardBackground, in: RoundedRectangle(cornerRadius: LiquidGlassStyle.cornerRadius))
            .shadow(color: .black.opacity(0.1), radius: LiquidGlassStyle.shadowRadius, x: 0, y: 4)
    }
    
    func liquidGlassNavBar() -> some View {
        self
            .background(LiquidGlassStyle.glassMaterial)
    }
    
    func liquidGlassButton(style: LiquidGlassButtonStyle = .primary) -> some View {
        self
            .padding()
            .frame(maxWidth: .infinity)
            .background(style.background, in: RoundedRectangle(cornerRadius: LiquidGlassStyle.cornerRadius))
            .foregroundStyle(style.foreground)
    }
}

enum LiquidGlassButtonStyle {
    case primary
    case secondary
    case accent
    
    var background: AnyShapeStyle {
        switch self {
        case .primary:
            return AnyShapeStyle(.ultraThinMaterial)
        case .secondary:
            return AnyShapeStyle(.thinMaterial)
        case .accent:
            return AnyShapeStyle(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }
    
    var foreground: AnyShapeStyle {
        switch self {
        case .primary:
            return AnyShapeStyle(.primary)
        case .secondary:
            return AnyShapeStyle(.secondary)
        case .accent:
            return AnyShapeStyle(.white)
        }
    }
}
