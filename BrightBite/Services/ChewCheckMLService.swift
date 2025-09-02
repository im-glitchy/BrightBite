//
//  ChewCheckMLService.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/1/25.
//

import UIKit
import Vision
import CoreML

// Mock CoreML service for development
// In production, this would use a trained SeeFood model

class ChewCheckMLService {
    static let shared = ChewCheckMLService()
    
    private init() {}
    
    func classifyFood(image: UIImage) async throws -> FoodClassification {
        // Simulate ML processing time
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Mock food classification results
        let mockFoods: [(String, Double, [FoodTag])] = [
            ("Yogurt", 0.89, [FoodTag.soft, FoodTag.cold]),
            ("Apple", 0.92, [FoodTag.hard, FoodTag.sugary]),
            ("Ice Cream", 0.87, [FoodTag.soft, FoodTag.cold, FoodTag.sugary]),
            ("Carrot", 0.91, [FoodTag.hard]),
            ("Pasta", 0.85, [FoodTag.soft, FoodTag.hot]),
            ("Granola Bar", 0.88, [FoodTag.hard, FoodTag.sticky, FoodTag.sugary]),
            ("Soup", 0.90, [FoodTag.soft, FoodTag.hot]),
            ("Bread", 0.86, [FoodTag.soft]),
            ("Nuts", 0.93, [FoodTag.hard]),
            ("Banana", 0.89, [FoodTag.soft])
        ]
        
        // Randomly select a classification (in real app, this would be based on the actual image)
        let classification = mockFoods.randomElement()!
        
        return FoodClassification(
            primaryResult: FoodResult(
                name: classification.0,
                confidence: classification.1,
                tags: classification.2
            ),
            alternatives: mockFoods
                .filter { $0.0 != classification.0 }
                .prefix(3)
                .map { FoodResult(name: $0.0, confidence: $0.1 * 0.8, tags: $0.2) }
        )
    }
    
    func analyzeFoodTags(_ tags: [FoodTag], against restrictions: [DietRestriction]) -> FoodVerdict {
        // Check restrictions against food tags
        for restriction in restrictions {
            switch restriction.type {
            case .softOnly:
                if tags.contains(.hard) || tags.contains(.chewy) {
                    return .avoid
                }
            case .noHard:
                if tags.contains(.hard) {
                    return .avoid
                }
            case .noSticky:
                if tags.contains(.sticky) {
                    return .avoid
                }
            case .noChewy:
                if tags.contains(.chewy) {
                    return .avoid
                }
            case .noHot:
                if tags.contains(.hot) {
                    return .avoid
                }
            case .noCold:
                if tags.contains(.cold) {
                    return .avoid
                }
            case .noSugary:
                if tags.contains(.sugary) {
                    return .caution
                }
            case .noAcidic:
                if tags.contains(.acidic) {
                    return .caution
                }
            }
        }
        
        // Additional caution checks
        if tags.contains(.sugary) || tags.contains(.acidic) {
            return .caution
        }
        
        // Check for temperature sensitivity timing
        if tags.contains(.hot) {
            return .later // Wait for it to cool down
        }
        
        return .safe
    }
}

struct FoodClassification {
    let primaryResult: FoodResult
    let alternatives: [FoodResult]
}

struct FoodResult {
    let name: String
    let confidence: Double
    let tags: [FoodTag]
}