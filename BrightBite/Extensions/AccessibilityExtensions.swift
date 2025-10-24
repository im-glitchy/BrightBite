//
//  AccessibilityExtensions.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/5/25.
//

import SwiftUI

extension View {
    func dentalAccessibility(label: String, hint: String? = nil, traits: AccessibilityTraits = []) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
    }
    
    func painLevelAccessibility(level: Double) -> some View {
        let description = painLevelDescription(level)
        return self
            .accessibilityLabel("Pain level \(Int(level)) out of 10")
            .accessibilityValue(description)
    }
    
    func foodVerdictAccessibility(verdict: FoodVerdict, foodName: String) -> some View {
        let description = foodVerdictDescription(verdict)
        return self
            .accessibilityLabel("\(foodName) is \(verdict.rawValue)")
            .accessibilityValue(description)
    }
    
    func toothAccessibility(number: Int, painLevel: Double) -> some View {
        let painDescription = painLevelDescription(painLevel)
        return self
            .accessibilityLabel("Tooth number \(number)")
            .accessibilityValue("Pain level: \(painDescription)")
            .accessibilityHint("Double tap to view tooth details")
    }
}

private func painLevelDescription(_ level: Double) -> String {
    switch level {
    case 0:
        return "No pain"
    case 0.1...2:
        return "Mild pain"
    case 2.1...4:
        return "Moderate pain"  
    case 4.1...6:
        return "Significant pain"
    case 6.1...8:
        return "Severe pain"
    case 8.1...10:
        return "Extreme pain"
    default:
        return "Pain level \(Int(level))"
    }
}

private func foodVerdictDescription(_ verdict: FoodVerdict) -> String {
    switch verdict {
    case .safe:
        return "Safe to eat with your current treatment"
    case .caution:
        return "Eat with caution, may need extra care"
    case .avoid:
        return "Avoid eating, may damage treatment"
    case .later:
        return "Wait before eating, timing matters"
    case .cannotIdentify:
        return "Cannot identify this item, avoid for safety"
    }
}


extension Color {
    static var accessiblePrimary: Color {
        Color.primary.opacity(UIAccessibility.isReduceTransparencyEnabled ? 1.0 : 0.8)
    }
    
    static var accessibleSecondary: Color {
        Color.secondary.opacity(UIAccessibility.isReduceTransparencyEnabled ? 1.0 : 0.6)
    }
    
    static func verdictColor(_ verdict: FoodVerdict, highContrast: Bool = UIAccessibility.isReduceTransparencyEnabled) -> Color {
        if highContrast {
            switch verdict {
            case .safe: return .green
            case .caution: return .orange
            case .avoid: return .red
            case .later: return .blue
            case .cannotIdentify: return .orange
            }
        } else {
            return verdict.color
        }
    }
}


extension Animation {
    static var accessible: Animation? {
        UIAccessibility.isReduceMotionEnabled ? nil : .easeInOut(duration: 0.3)
    }
    
    static var accessibleSpring: Animation? {
        UIAccessibility.isReduceMotionEnabled ? nil : .spring(response: 0.5, dampingFraction: 0.8)
    }
}


extension Font {
    static var accessibleCaption: Font {
        .system(.caption, design: .default).weight(.regular)
    }
    
    static var accessibleBody: Font {
        .system(.body, design: .default).weight(.regular)
    }
    
    static var accessibleHeadline: Font {
        .system(.headline, design: .default).weight(.semibold)
    }
    
    static var accessibleTitle: Font {
        .system(.title2, design: .default).weight(.bold)
    }
}
